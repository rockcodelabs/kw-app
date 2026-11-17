# frozen_string_literal: true

module Management
  module Voting
    class CreateCase
      include Dry::Monads[:result]

      def initialize(form)
        @form = form
      end

      def call(raw_inputs:)
        form_outputs = form.new.call(raw_inputs.to_unsafe_h)
        return Failure(form_outputs.errors(locale: :pl).to_h) unless form_outputs.success?

        case_record = Management::Voting::CaseRecord.create(form_outputs.to_h)
        case_record.update meeting_type: 1
        if case_record.hide_votes?
          case_record.update state: 'finished'
        end

        Management::Voting::Repository.new.management_users.each do |user|
          NotificationCenter::NotificationRecord.create(
            recipient_id: user.id,
            actor_id: case_record.creator_id,
            action: 'created_voting',
            notifiable_id: case_record.id,
            notifiable_type: 'Management::Voting::CaseRecord'
          )
          Management::Voting::Mailer.notify(case_record.id, user.id).deliver_later
        end unless case_record.hide_votes?

        Success(:success)
      end

      private

      attr_reader :form
    end
  end
end
