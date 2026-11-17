# frozen_string_literal: true

module Events
  module Admin
    module Competitions
      class CreateForm < Dry::Validation::Contract
        params do
          required(:name).filled(:string)
          required(:email_text).filled(:string)
          required(:edition_sym).filled(:string)
          optional(:results_url)
          optional(:rules)
          optional(:baner)
          optional(:single)
          optional(:team_name)
          optional(:event_date)
          optional(:accept_first)
          optional(:rules_text)
          optional(:sign_up_starts_at)
          optional(:weekend_nights)
          optional(:closed)
          optional(:limit)
          optional(:custom_form)
          optional(:en_email_text)
          optional(:matrimonial_office)
          optional(:tshirt_url)
          optional(:alert)
          optional(:close_payment)
          optional(:medical_rules_text)
          optional(:weekend_nights_text)
          optional(:organizer_email)
          optional(:info_above_sign_ups)
          optional(:package_types_attributes)
        end
      end
    end
  end
end
