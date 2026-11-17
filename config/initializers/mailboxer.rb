Rails.application.config.to_prepare do
Mailboxer.setup do |config|
  #Configures if your application uses or not email sending for Notifications and Messages
  config.uses_emails = true

  config.message_mailer = Messaging::Mailers::MessageMailer
  #Configures the default from for emails sent for Messages and Notifications
  config.default_from = "no-reply@kw.krakow.pl"

  #Configures the methods needed by mailboxer
  config.email_method = :mailboxer_email
  config.name_method = :display_name
  config.notify_method = :notify

  #Configures if you use or not a search engine and which one you are using
  #Supported engines: [:solr,:sphinx,:pg_search]
  config.search_enabled = false
  config.search_engine = :pg_search

  #Configures maximum length of the message subject and body
  config.subject_max_length = 255
  config.body_max_length = 32000
end
end

Rails.application.config.to_prepare do
  Mailboxer::Message.class_eval do
    #after_save :create_notification

    def create_notification
      recipients.each do |recipient|
        NotificationCenter::NotificationRecord.create(
          recipient_id: recipient.id,
          actor_id: sender_id,
          action: 'created_message',
          notifiable_id: id,
          notifiable_type: 'Mailboxer::Message'
        )
      end
    end
  end

  Mailboxer::Conversation.class_eval do
    before_create :set_code

    has_many :course_conversations, class_name: '::Business::CourseConversationRecord', :dependent => :destroy, foreign_key: :conversation_id
    has_many :courses, :through => :course_conversations, foreign_key: :course_id

    has_many :conversation_items,
      class_name: 'Messaging::ConversationItemRecord',
      foreign_key: :conversation_id

    has_many :sign_ups,
      through: :conversation_items,
      source: :messageable,
      source_type: 'Business::SignUpRecord'

    has_many :business_courses,
      through: :conversation_items,
      source: :messageable,
      source_type: 'Business::CourseRecord'

    has_many :supplementary_courses,
      through: :conversation_items,
      source: :messageable,
      source_type: 'Training::Supplementary::CourseRecord'

    def set_code
      self.code = loop do
        random_token = SecureRandom.hex(8)
        break random_token unless ::Mailboxer::Conversation.exists?(code: random_token)
      end
    end
  end
end
