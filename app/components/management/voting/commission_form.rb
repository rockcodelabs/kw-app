# frozen_string_literal: true

module Management
  module Voting
    class CommissionForm < Dry::Validation::Contract
      config.messages.load_paths << 'app/components/management/errors.yml'

      params do
      required(:approval).filled(:bool)
      required(:owner_id).filled(:integer)
      required(:authorized_id).filled(:integer)
      end
    end
  end
end
