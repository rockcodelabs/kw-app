# frozen_string_literal: true

module Management
  module Voting
    class CaseForm < Dry::Validation::Contract
      config.messages.load_paths << 'app/components/management/errors.yml'

      params do
      required(:name).filled(:string)
      required(:creator_id).filled(:integer)
      required(:voting_type).filled(:string)
      optional(:public).maybe(:bool)
      optional(:meeting_type).filled
      optional(:state)
      optional(:position)
      optional(:hidden).maybe(:bool)
      optional(:acceptance_date).maybe(:date_time)
      optional(:destrciption).maybe(:string)
      optional(:final_voting_result).maybe(:string)
      optional(:who_ids)
      optional(:number).maybe(:string)
      optional(:doc_url).maybe(:string)
      optional(:hide_votes).maybe(:bool)
      optional(:attachments)
      end
    end
  end
end
