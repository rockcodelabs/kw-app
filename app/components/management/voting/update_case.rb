# frozen_string_literal: true

module Management
  module Voting
    class UpdateCase
      include Dry::Monads[:result]

      def initialize(form)
        @form = form
      end

      def call(id:, raw_inputs:)
        form_outputs = form.new.call(raw_inputs.to_unsafe_h)
        return Failure(form_outputs.errors(locale: :pl).to_h) unless form_outputs.success?

        case_record = Management::Voting::CaseRecord.find(id)
        case_record.update(form_outputs.to_h)

        Success(case_record.id)
      end

      private

      attr_reader :form
    end
  end
end
