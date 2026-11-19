require "active_support/core_ext/integer/time"

# The test environment is used exclusively to run your application's
# test suite. You never need to work with it otherwise. Remember that
# your test database is "scratch space" for the test suite and is wiped
# and recreated between test runs. Don't rely on the data there!
require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Turn false under Spring and add config.action_view.cache_template_loading = true.
  config.cache_classes = true

  # Eager loading loads your whole application. When running a single test locally,
  # this may not be necessary. It's a good idea to do in a continuous integration system,
  # or in some way before deploying your code.
  config.eager_load = ENV["CI"].present?

  # Configure logging for test environment
  # Use :warn to hide SQL queries and debug logs by default
  # Set VERBOSE_TESTS=true environment variable to see full debug output
  config.log_level = ENV['VERBOSE_TESTS'].present? ? :debug : :warn
  config.logger = ActiveSupport::Logger.new(STDOUT)
  config.logger.formatter = proc { |severity, datetime, progname, msg|
    "[#{datetime.strftime('%H:%M:%S.%L')}] #{severity} | #{msg}\n"
  }
  
  # Silence ActiveRecord SQL logging unless verbose mode is enabled
  unless ENV['VERBOSE_TESTS'].present?
    ActiveRecord::Base.logger = ActiveSupport::Logger.new(nil)
  end

  # Configure public file server for tests with Cache-Control for performance.
  config.public_file_server.enabled = true
  config.public_file_server.headers = {
    "Cache-Control" => "public, max-age=#{1.hour.to_i}"
  }

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false
  config.cache_store = :null_store

  # Raise exceptions instead of rendering exception templates.
  config.action_dispatch.show_exceptions = false

  # Disable request forgery protection in test environment.
  config.action_controller.allow_forgery_protection = false

  # Disable host authorization in test environment
  # Clear hosts array to allow all hosts (Rails 7 behavior)
  config.hosts.clear
  
  # Add test hosts for request specs
  config.hosts << 'www.example.com'
  config.hosts << 'example.com'

  # Store uploaded files on the local file system in a temporary directory.
  config.active_storage.service = :test

  config.action_mailer.perform_caching = false

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test
  # Mail templates build absolute links (payment, cancel, contract); production and staging set this too.
  config.action_mailer.default_url_options = { host: 'http://www.example.com' }

  # Print deprecation notices to the stderr.
  config.active_support.deprecation = :stderr

  # Raise exceptions for disallowed deprecations.
  config.active_support.disallowed_deprecation = :raise

  # Tell Active Support which deprecation messages to disallow.
  config.active_support.disallowed_deprecation_warnings = []

  # Raises error for missing translations.
  # config.i18n.raise_on_missing_translations = true

  # Annotate rendered view with file names.
  # config.action_view.annotate_rendered_view_with_filenames = true
end
