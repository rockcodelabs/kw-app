# Redis is reached through REDIS_URL_SIDEKIQ + REDIS_PASSWORD (env first, credentials as fallback).
redis_config = lambda do
  {
    password: ENV.fetch('REDIS_PASSWORD') { Rails.application.credentials.dig(:redis, :password) },
    url: ENV.fetch('REDIS_URL_SIDEKIQ') { Rails.application.credentials.dig(:redis, :url) }
  }
end

Sidekiq.configure_server { |config| config.redis = redis_config.call }
Sidekiq.configure_client { |config| config.redis = redis_config.call }
