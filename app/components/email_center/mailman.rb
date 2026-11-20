module EmailCenter
  class Mailman
    def initialize(email)
      @email = email
      @to = pick_meaningful_recipient(email.to)
      @from = email.from
      @body = email.body
    end

    def handle_it
      conversation_code = @to&.dig(:token)&.split('+')&.last
      return true unless conversation_code

      conversation = ::Mailboxer::Conversation.find_by(code: conversation_code)

      sender = nil
      if conversation && conversation.courses.any?
        if Db::User.find_by(email: @from[:email])
          sender = Db::User.find_by(email: @from[:email])
        else
          sender = ::Business::SignUpRecord.find_by(email: @from[:email])
        end
      else
        sender = Db::User.find_by(email: @from[:email])
      end

      if sender && conversation
        sender.reply_to_conversation(conversation, @body)
      end
      true
    end

    private

    def pick_meaningful_recipient(recipients)
      recipients.find { |address| address[:host] =~ /panel.kw.krakow.pl/ }
    end
  end
end
