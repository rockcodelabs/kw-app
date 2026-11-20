# Set USE_LOCAL_STORAGE=true environment variable to use local file storage in development
# This avoids ad blocker issues with OpenStack URLs
# Always use local storage in test environment
USE_LOCAL_STORAGE = (ENV['USE_LOCAL_STORAGE'] == 'true' && Rails.env.development?) || Rails.env.test?

# CarrierWave's default cache is public/uploads/tmp, which the app serves as static files and which is never
# cleaned. Keep it under tmp/ (outside public/, discarded with the container on every deploy).
CarrierWave.configure do |config|
  config.cache_dir = Rails.root.join('tmp/uploads').to_s
end

if USE_LOCAL_STORAGE
  # Use local file storage for development and test
  CarrierWave.configure do |config|
    config.storage = :file
    config.root = Rails.root.join('public')
    config.asset_host = Rails.env.test? ? nil : "http://localhost:3002"
    Rails.logger.info "CarrierWave: Using local file storage (#{Rails.env})"
  end
else
  require "fog/openstack"

  # Use cloud storage (OpenStack)
  CarrierWave.configure do |config|
    config.fog_credentials = {
      provider: 'openstack',
      openstack_api_key: Rails.application.credentials.dig(:openstack, :api_key),
      openstack_username: Rails.application.credentials.dig(:openstack, :username),
      openstack_auth_url: "https://auth.cloud.ovh.net/",
      openstack_region: 'WAW',
      connection_options: {
        connect_timeout: 60,
        read_timeout: 60,
        write_timeout: 60,
        persistent: false,
        # Add instrumentation callbacks for debugging
        instrumentor: ActiveSupport::Notifications,
        instrumentor_name: 'excon'
      }
    }
    # Use environment-specific container
    container_name = "kw-app-cloud-#{Rails.env}"
    
    config.fog_directory = container_name
    # Use public URLs for all environments - let Fog generate URLs automatically
    # Setting fog_public = true allows public access without authentication tokens
    config.fog_public = true
    
    # Don't set asset_host - let Fog generate proper URLs with container name included
    # Fog will automatically generate URLs like:
    # https://storage.waw.cloud.ovh.net/v1/AUTH_xxx/container-name/path/to/file.png
    
    Rails.logger.info "CarrierWave: Using OpenStack fog storage with container: #{container_name}"
    Rails.logger.info "CarrierWave: persistent=false, timeouts=60s"
  end
end

# Subscribe to Excon events for connection monitoring
ActiveSupport::Notifications.subscribe('excon.request') do |name, start, finish, id, payload|
  duration = ((finish - start) * 1000).round(2)
  if duration > 5000
    Rails.logger.warn "[EXCON] Slow request: #{duration}ms to #{payload[:host]}#{payload[:path]}"
  end
  if payload[:response]
    status = payload[:response][:status]
    if status >= 500
      Rails.logger.error "[EXCON] Server error #{status}: #{payload[:host]}#{payload[:path]}"
    end
  end
end

ActiveSupport::Notifications.subscribe('excon.error') do |name, start, finish, id, payload|
  Rails.logger.error "[EXCON] Connection error: #{payload[:error].class} - #{payload[:error].message}"
  Rails.logger.error "[EXCON] Host: #{payload[:host]}, Path: #{payload[:path]}"
end

# Fix CarrierWave::Storage::Fog::File blank? issue
# The Fog::File object returns size: 0 and empty?: true even when files exist in OpenStack
# This causes blank? to return true incorrectly
# We override blank? and present? to check URL presence instead
module CarrierWave
  module Storage
    class Fog
      class File
        def blank?
          # For Fog storage, check if URL is blank instead of relying on size/empty?
          # which don't work correctly with lazy-loaded remote files
          url.blank?
        end
        
        def present?
          !blank?
        end
      end
    end
  end
end

Rails.logger.info "CarrierWave: Patched Fog::File blank?/present? to use URL presence check"