# frozen_string_literal: true

module Management
  module Voting
    class CreateCommission
      include Dry::Monads[:result]

      def initialize(form)
        @form = form
      end

      def call(raw_inputs:)
        commission_record = Management::Voting::CommissionRecord.new(raw_inputs)

        if commission_record.save
          Management::Voting::Mailer.notify_commission(commission_record.id).deliver_later

          Success(commission_record)
        else
          Failure(commission_record.errors.full_messages)
        end
      end

      private

      attr_reader :form
    end
  end
end
