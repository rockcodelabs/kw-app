# frozen_string_literal: true

module Settlement
  class ContractorForm < Dry::Validation::Contract
    config.messages.load_paths << 'app/components/settlement/errors.yml'

    params do
      required(:name).filled
      optional(:nip)
      optional(:logo)
      optional(:phone)
      optional(:email)
      optional(:www)
      optional(:contact_name)
      required(:reason_type).filled
      required(:profession_type).filled
      optional(:description)
    end

    rule(:nip) do
      key.failure(:unique_nip) if value.present? && Settlement::ContractorRecord.exists?(nip: value)
    end
  end
end
