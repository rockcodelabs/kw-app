class RegistrationsController < Devise::RegistrationsController
  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(
      :account_update, keys: [
        :snw_blog, :facebook_url, :instagram_url, :website_url, :description,
        :avatar, :hide, :climbing_boars, :boars, :ski_hater, :first_name,
        :last_name, :phone, :email, :kw_id, :password, :password_confirmation,
        :current_password, :strava_client_secret, :strava_client_id, :strava_subscribe
      ]
    )
    devise_parameter_sanitizer.permit(
      :sign_up, keys: [:first_name, :last_name, :phone, :email, :kw_id]
    )
  end

  def update_resource(resource, params)
    resource.reset_password(params[:password], params[:password]) if params[:password].present?
    resource.update_without_password(params)

    if resource.strava_token && resource.strava_subscribe?
      if strava_client(resource.strava_client_id, resource.strava_client_secret).push_subscriptions.any?
      else
        subscription = strava_client(resource.strava_client_id, resource.strava_client_secret)
          .create_push_subscription(callback_url: 'https://panel.kw.krakow.pl/activities/api/strava_activities/callback', verify_token: Rails.application.secrets.strava_verify_token)
        resource.update(strava_subscription_id: subscription&.id) unless resource.strava_subscription_id
      end
    else
      if strava_client(resource.strava_client_id, resource.strava_client_secret).push_subscriptions.any?
        strava_client(resource.strava_client_id, resource.strava_client_secret)
          .delete_push_subscription(resource.strava_subscription_id) if resource.strava_subscription_id
        resource.update(strava_subscription_id: nil)
      else
        resource.update(strava_subscription_id: nil)
      end
    end
    resource
  rescue Strava::Errors::Fault
    resource
  end

  def after_update_path_for(resource)
    edit_user_registration_path
  end

  def strava_client(client_id, client_secret)
    Strava::Webhooks::Client.new(
      client_id: client_id,
      client_secret: client_secret
    )
  end
end
