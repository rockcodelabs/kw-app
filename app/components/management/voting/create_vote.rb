# frozen_string_literal: true

module Management
  module Voting
    class CreateVote
      include Dry::Monads[:result]

      def initialize(form)
        @form = form
      end

      def call(raw_inputs:, current_user_id:)
        form_outputs = form.new.call(raw_inputs.to_unsafe_h)
        return Failure(raw_inputs[:case_id]) unless form_outputs.success?

        case_record = Management::Voting::CaseRecord.find_by(id: raw_inputs[:case_id])
        return Failure(raw_inputs[:case_id]) unless case_record&.voting?

        vote_record = Management::Voting::VoteRecord.new(form_outputs.to_h)

        if form_outputs[:user_id] != current_user_id
          unless Management::Voting::CommissionRecord.exists?(authorized_id: current_user_id, owner_id: form_outputs[:user_id])
            return Failure(raw_inputs[:case_id])
          end
        end

        if vote_record.save
          Success(vote_record.case_id)
        else
          Failure(raw_inputs[:case_id])
        end
      end

      private

      attr_reader :form
    end
  end
end
