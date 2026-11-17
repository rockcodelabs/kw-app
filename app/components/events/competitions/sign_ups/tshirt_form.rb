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
      class TshirtForm < Dry::Validation::Contract
        config.messages.load_paths << 'app/components/events/competitions/sign_ups/errors.yml'
        option :competition_id

        params do
          required(:participant_name_1).filled(:string)
          required(:tshirt_size_1).filled(:string)
          required(:competition_package_type_1_id).filled(:integer)
          optional(:participant_phone_1).maybe(:string)
          optional(:participant_kw_id_1).maybe(:integer)
        end

        rule(:participant_kw_id_1, :competition_package_type_1_id) do
          package = Events::Db::CompetitionPackageTypeRecord.find_by(id: values[:competition_package_type_1_id])

          if package&.membership? && !::Membership::Activement.new(user: ::Db::User.find_by(kw_id: values[:participant_kw_id_1])).active?
            key(:participant_kw_id_1).failure(:active_kw_id_1)
          end
        end
      end
    end
  end
end
