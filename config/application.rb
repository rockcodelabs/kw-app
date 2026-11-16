require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module KwApp
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    # Must be set here, not in an initializer: with lazy-loaded models (dev/test) the initializer
    # runs too late, so dev/test required belongs_to while eager-loaded staging/production did not.
    config.active_record.belongs_to_required_by_default = false

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
    #

    # Configure lib/ directory for autoloading (Rails 7.0 manual setup)
    # Note: Rails 7.1+ can use config.autoload_lib(ignore: %w[...]) instead
    lib = root.join("lib")
    
    # Add lib/locales to I18n load path for translations
    config.i18n.load_path += Dir[root.join('lib', 'locales', '**', '*.{rb,yml}')]
    config.autoload_paths += [lib]
    config.eager_load_paths += [lib]
    
    # Ignore non-code subdirectories in lib/
    # Note: lib/locales must be ignored from autoloader but kept in I18n load path
    Rails.autoloaders.main.ignore(
      lib.join("tasks"),
      lib.join("seeding"),
      lib.join("playwright"),
      lib.join("locales")
    )

  end
end
