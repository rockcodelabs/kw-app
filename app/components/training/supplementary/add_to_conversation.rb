module Training
  module Supplementary
    class AddToConversation
      include Dry::Monads[:result]

      def initialize(repository)
        @repository = repository
      end

      def call(course_id:)
        return Failure(:no_course) unless Training::Supplementary::CourseRecord.exists?(id: course_id)
        course = Training::Supplementary::CourseRecord.find(course_id)
        return Failure(:no_conversation) unless course.conversation_at && course.conversations.any?

        conversation = course.original_conversation
        repository.users_signed_in(course_id).each do |participant|
          unless conversation.is_participant?(participant)
            conversation.add_participant(participant)

            ::Messaging::Mailers::MessageMailer.add_participant(conversation.original_message, participant).deliver_later
          end
        end

        Success(:success)
      end

      private

      attr_reader :repository
    end
  end
end
