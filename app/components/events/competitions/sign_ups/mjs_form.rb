# frozen_string_literal: true

require 'dry-validation'
require 'dry-types'
Dry::Types.load_extensions(:maybe)
module Types
  include Dry.Types(default: :nominal)
end

module Events
  module Competitions
    module SignUps
      class MjsForm < Dry::Validation::Contract
        config.messages.load_paths << 'app/components/events/competitions/sign_ups/errors.yml'
        option :competition_id

        params do
         required(:participant_first_name_1).filled
         required(:participant_name_1).filled
         required(:participant_country_1).filled
         optional(:tshirt_size_1).filled
         optional(:participant_city_1)
         optional(:team_name)
         optional(:teammate_id)
         optional(:remarks)
         optional(:license_number)
         optional(:participant_kw_id_1).maybe(:string)
         optional(:participant_license_id_1)
         optional(:participant_team_1)
         required(:participant_phone_1).filled
         required(:participant_phone_2).filled
         required(:participant_gender_1).filled
         required(:participant_email_1).filled(:string, format?: /.@.+[.][a-z]{2,}/i)
         required(:participant_birth_year_1).filled
         required(:competition_package_type_1_id).filled
         optional(:rescuer)
         optional(:friday_night)
         optional(:saturday_night)
         required(:terms_of_service).filled
         required(:medical_rules).filled
        end

        rule(:participant_kw_id_1, :competition_package_type_1_id) do
          package = Events::Db::CompetitionPackageTypeRecord.find_by(id: values[:competition_package_type_1_id])

          if package&.membership? && !::Membership::Activement.new(user: ::Db::User.find_by(kw_id: values[:participant_kw_id_1])).active?
            key(:participant_kw_id_1).failure(:active_kw_id_1)
          end
        end

        rule(:participant_birth_year_1, :competition_package_type_1_id) do
          package = Events::Db::CompetitionPackageTypeRecord.find_by(id: values[:competition_package_type_1_id])

          if package&.junior_year.present? && package.junior_year > values[:participant_birth_year_1].to_i
            key(:participant_birth_year_1).failure(:correct_junior_category_1)
          end
        end

        rule(:terms_of_service) do
          key.failure(:terms_of_service_true) unless ActiveRecord::Type::Boolean.new.cast(value)
        end

        rule(:medical_rules) do
          key.failure(:medical_rules_true) unless ActiveRecord::Type::Boolean.new.cast(value)
        end
      end
    end
  end
end
