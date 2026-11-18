require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.cache_classes = true

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # Ensures that a master key has been made available in either ENV["RAILS_MASTER_KEY"]
  # or in config/master.key. This key is used to decrypt credentials (and other encrypted files).
  # config.require_master_key = true

  # Disable serving static files from the `/public` folder by default since
  # Apache or NGINX already handles this.
  config.public_file_server.enabled = true

  # Compress JavaScripts and CSS.
  config.assets.js_compressor = Uglifier.new(harmony: true)

  # config.assets.css_compressor = :sass

  # Do not fallback to assets pipeline if a precompiled asset is missed.
  config.assets.compile = false

  # `config.assets.precompile` and `config.assets.version` have moved to config/initializers/assets.rb

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # Read at runtime only (ASSET_HOST is set in config/deploy.production.yml). It must stay unset
  # during `assets:precompile`, otherwise the host is baked into url() in the compiled CSS (fonts, images).
  config.action_controller.asset_host = ENV['ASSET_HOST'].presence

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = 'X-Sendfile' # for Apache
  # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for NGINX

  # Store uploaded files on the local file system (see config/storage.yml for options)
  config.active_storage.service = :local

  # Mount Action Cable outside main process or domain
  # config.action_cable.mount_path = nil
  # config.action_cable.url = 'wss://example.com/cable'
  # config.action_cable.allowed_request_origins = [ 'http://example.com', /http:\/\/example.*/ ]

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # kamal-proxy terminates TLS and forwards X-Forwarded-Proto (proxy.forward_headers). Its health probe hits /up over
  # plain HTTP with the container id as Host, so /up is exempt from the redirect and from host authorization.
  config.force_ssl = true
  config.ssl_options = { redirect: { exclude: ->(request) { request.path == '/up' } } }

  # Both panel hostnames are allowed so the cutover (nowypanel -> panel) needs no change here.
  config.hosts << 'nowypanel.kw.krakow.pl'
  config.hosts << 'panel.kw.krakow.pl'
  config.host_authorization = { exclude: ->(request) { request.path == '/up' } }

  # :info keeps request and error lines but drops SQL/param debug noise (and personal data) from the logs.
  config.log_level = :info

  # Prepend all log lines with the following tags.
  config.log_tags = [ :request_id ]

  # Use a different cache store in production.
  # config.cache_store = :mem_cache_store

  # Use a real queuing backend for Active Job (and separate queues per environment)
  # master set this globally in config/application.rb; the Rails 6.1 upgrade (9fc768e5) dropped it, which silently
  # moved every deliver_later onto the in-process :async adapter (no persistence, no retries, no Sidekiq UI).
  config.active_job.queue_adapter = :sidekiq
  # config.active_job.queue_adapter     = :resque
  # config.active_job.queue_name_prefix = "kw_app_#{Rails.env}"
  config.action_mailer.perform_caching = false
  config.action_mailer.default_url_options = { host: 'https://nowypanel.kw.krakow.pl' }
  config.action_mailer.delivery_method = :mailgun
  config.action_mailer.mailgun_settings = {
    api_key: ENV.fetch('MAILGUN_API_KEY') { Rails.application.credentials.dig(:mailgun, :api_key) },
    domain: ENV.fetch('MAILGUN_DOMAIN') { Rails.application.credentials.dig(:mailgun, :domain) },
  }
  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Use default logging formatter so that PID and timestamp are not suppressed.
  config.log_formatter = ::Logger::Formatter.new

  # A custom logger ignores config.log_level, so the level is set on it explicitly.
  config.logger = Logger.new(STDOUT, level: Logger::INFO)


  # Use a different logger for distributed setups.
  # require "syslog/logger"
  # config.logger = ActiveSupport::TaggedLogging.new(Syslog::Logger.new "app-name")

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false
end
Rails.application.routes.default_url_options[:host] = 'https://nowypanel.kw.krakow.pl'
