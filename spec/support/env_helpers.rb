# frozen_string_literal: true

# Sets environment variables for the duration of a block (nil unsets) and restores them afterwards.
# Kept here instead of the climate_control gem to avoid a new dependency.
module EnvHelpers
  def with_env(values)
    saved = values.keys.to_h { |key| [key, ENV.fetch(key, nil)] }
    values.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    saved.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end

RSpec.configure { |config| config.include EnvHelpers }
