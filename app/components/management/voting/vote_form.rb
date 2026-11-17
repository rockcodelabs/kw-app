# frozen_string_literal: true

module Management
  module Voting
    class VoteForm < Dry::Validation::Contract
      config.messages.load_paths << 'app/components/management/errors.yml'

      params do
      optional(:decision).maybe(:string)
      optional(:user_ids)
      required(:case_id).filled(:integer)
      required(:user_id).filled(:integer)
      required(:commission).filled(:bool)
      required(:authorized_id).filled(:integer)
      end
    end
  end
end
