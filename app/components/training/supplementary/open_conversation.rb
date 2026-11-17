module Training
  module Supplementary
    class OpenConversation
      include Dry::Monads[:result]

      def initialize(repository)
        @repository = repository
      end

      def call(course_id:)
        course = Training::Supplementary::CourseRecord.find(course_id)
        return Failure(:already_exists) if course.conversation_at
        return Failure(:no_participants) unless repository.users_signed_in(course_id).any?

        receipt = course.organizer.send_message(
          repository.users_signed_in(course_id),
          "Tutaj możecie kontaktować się w sprawie dojazdu, po wydarzeniu z instruktorem, koordynatorem. Konwersacja jest widoczna tylko dla uczestników",
          "[#{course.start_date.to_date}] #{course.name}"
        )
        Messaging::ConversationItemRecord.create(
          conversation_id: receipt.conversation.id,
          messageable_type: 'Training::Supplementary::CourseRecord',
          messageable_id: course.id
        )
        course.update(conversation_at: Time.current)

        Success(:success)
      end

      private

      attr_reader :repository
    end
  end
end
