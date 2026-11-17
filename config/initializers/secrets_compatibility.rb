# Secrets Compatibility Layer
# This initializer provides backward compatibility during migration from secrets.yml to credentials
# It allows Rails.application.secrets to fallback to credentials when a secret is not found

module SecretsCompatibility
  # Meteoblue
  def meteoblue_key
    super.presence || ENV.fetch('METEOBLUE_KEY') { Rails.application.credentials.dig(:meteoblue, :api_key) }
  end
  
  # Dotpay
  def dotpay_base_url
    super.presence || Rails.application.credentials.dig(:payment, :dotpay_base_url) || 'https://ssl.dotpay.pl/s2/login/api/v1/'
  end
  
  def dotpay_login
    super.presence || ENV.fetch('DOTPAY_LOGIN') { Rails.application.credentials.dig(:payment, :dotpay_login) }
  end
  
  def dotpay_password
    super.presence || ENV.fetch('DOTPAY_PASSWORD') { Rails.application.credentials.dig(:payment, :dotpay_password) }
  end
  
  def dotpay_back_url
    super.presence || ENV.fetch('DOTPAY_BACK_URL') { Rails.application.credentials.dig(:payment, :dotpay_back_url) }
  end
  
  def dotpay_back_24_url
    super.presence || ENV.fetch('DOTPAY_BACK_24_URL') { Rails.application.credentials.dig(:payment, :dotpay_back_24_url) }
  end
  
  def dotpay_urlc
    super.presence || ENV.fetch('DOTPAY_URLC') { Rails.application.credentials.dig(:payment, :dotpay_urlc) }
  end
  
  def dotpay_fees_id
    super.presence || ENV.fetch('DOTPAY_FEES_ID') { Rails.application.credentials.dig(:payment, :dotpay_fees_id) }
  end
  
  def dotpay_reservations_id
    super.presence || ENV.fetch('DOTPAY_RESERVATIONS_ID') { Rails.application.credentials.dig(:payment, :dotpay_reservations_id) }
  end
  
  def dotpay_trainings_id
    super.presence || ENV.fetch('DOTPAY_TRAININGS_ID') { Rails.application.credentials.dig(:payment, :dotpay_trainings_id) }
  end
  
  def dotpay_donations_id
    super.presence || ENV.fetch('DOTPAY_DONATIONS_ID') { Rails.application.credentials.dig(:payment, :dotpay_donations_id) }
  end
  
  def dotpay_donations_other_id
    super.presence || ENV.fetch('DOTPAY_DONATIONS_OTHER_ID') { Rails.application.credentials.dig(:payment, :dotpay_donations_other_id) }
  end
  
  def dotpay_club_trips_id
    super.presence || ENV.fetch('DOTPAY_CLUB_TRIPS_ID') { Rails.application.credentials.dig(:payment, :dotpay_club_trips_id) }
  end
  
  def dotpay_shop_id
    super.presence || ENV.fetch('DOTPAY_SHOP_ID') { Rails.application.credentials.dig(:payment, :dotpay_shop_id) }
  end
  
  # OpenStack
  def openstack_api_key
    super.presence || ENV.fetch('OPENSTACK_API_KEY') { Rails.application.credentials.dig(:openstack, :api_key) }
  end
  
  def openstack_username
    super.presence || ENV.fetch('OPENSTACK_USERNAME') { Rails.application.credentials.dig(:openstack, :username) }
  end
  
  def openstack_tenant
    super.presence || ENV.fetch('OPENSTACK_TENANT') { Rails.application.credentials.dig(:openstack, :tenant) }
  end
  
  def openstack_asset_host
    super.presence || ENV.fetch('OPENSTACK_ASSET_HOST') { Rails.application.credentials.dig(:openstack, :asset_host) }
  end
  
  # Mailgun
  def mailgun_api_key
    super.presence || ENV.fetch('MAILGUN_API_KEY') { Rails.application.credentials.dig(:mailgun, :api_key) }
  end
  
  def mailgun_login
    super.presence || ENV.fetch('MAILGUN_LOGIN') { Rails.application.credentials.dig(:mailgun, :login) }
  end
  
  def mailgun_password
    super.presence || ENV.fetch('MAILGUN_PASSWORD') { Rails.application.credentials.dig(:mailgun, :password) }
  end
  
  def mailgun_domain
    super.presence || ENV.fetch('MAILGUN_DOMAIN') { Rails.application.credentials.dig(:mailgun, :domain) }
  end
  
  # Strava
  def strava_client
    super.presence || ENV.fetch('STRAVA_CLIENT') { Rails.application.credentials.dig(:strava, :client_id) }
  end
  
  def strava_secret
    super.presence || ENV.fetch('STRAVA_SECRET') { Rails.application.credentials.dig(:strava, :client_secret) }
  end
  
  def strava_verify_token
    super.presence || ENV.fetch('STRAVA_VERIFY_TOKEN') { Rails.application.credentials.dig(:strava, :verify_token) }
  end

  # Pages
  def strzelecki_page
    super.presence || Rails.application.credentials.dig(:pages, :strzelecki)
  end
  
  def mas_page
    super.presence || Rails.application.credentials.dig(:pages, :mas)
  end
  
  def localtunnel
    super.presence || Rails.application.credentials.dig(:pages, :localtunnel)
  end
  
  # Google
  def google_analytics
    super.presence || Rails.application.credentials.dig(:google, :analytics)
  end
end

Rails.application.config.after_initialize do
  Rails.application.secrets.singleton_class.prepend(SecretsCompatibility)
end