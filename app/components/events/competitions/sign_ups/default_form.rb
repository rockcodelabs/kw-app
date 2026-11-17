# frozen_string_literal: true

module Events
  module Competitions
    module SignUps
      class DefaultForm < Dry::Validation::Contract
        config.messages.load_paths << 'app/components/events/competitions/sign_ups/errors.yml'
        option :competition_id, default: -> {}

        params do
          required(:participant_name_1).filled
          optional(:tshirt_size_1).filled
          optional(:participant_city_1)
          optional(:team_name)
          optional(:teammate_id)
          optional(:remarks)
          optional(:participant_team_1)
          required(:participant_gender_1).filled
          required(:participant_email_1).filled(:string, format?: /.@.+[.][a-z]{2,}/i)
          required(:participant_birth_year_1).filled
          required(:competition_package_type_1_id).filled
          optional(:participant_kw_id_1)
          required(:terms_of_service).filled
          optional(:participant_country_1)
          optional(:participant_license_id_1)
        end

        rule(:terms_of_service) do
          key.failure(:terms_of_service_true) unless ActiveRecord::Type::Boolean.new.cast(value)
        end

        rule(:participant_country_1, :participant_license_id_1, :competition_package_type_1_id) do
          package = Events::Db::CompetitionPackageTypeRecord.find_by(id: values[:competition_package_type_1_id])

          if values[:participant_country_1] == 'pl' && package&.name == 'Puchar Polski'
            key(:participant_license_id_1).failure(:participant_license_1_filled) if values[:participant_license_id_1].blank? || values[:participant_license_id_1] == '0'
          end
        end
      end
    end
  end
end
