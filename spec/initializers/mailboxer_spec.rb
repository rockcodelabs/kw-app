# frozen_string_literal: true

require 'rails_helper'

# config/initializers/mailboxer.rb once nested one `to_prepare` in another. The inner
# block never ran, so none of these extensions existed.
RSpec.describe 'Mailboxer initializer' do
  around do |example|
    original = ActionMailer::Base.default_url_options
    ActionMailer::Base.default_url_options = { host: 'panel.example.com' }
    example.run
  ensure
    ActionMailer::Base.default_url_options = original
  end

  it 'uses the application message mailer' do
    expect(Mailboxer.message_mailer).to eq(Messaging::Mailers::MessageMailer)
  end

  it 'extends Mailboxer::Conversation with course and sign up associations' do
    expect(Mailboxer::Conversation.reflect_on_association(:sign_ups)).to be_present
    expect(Mailboxer::Conversation.reflect_on_association(:supplementary_courses)).to be_present
    expect(Mailboxer::Conversation.reflect_on_association(:business_courses)).to be_present
    expect(Mailboxer::Conversation.reflect_on_association(:courses)).to be_present
  end

  it 'assigns a unique code to new conversations' do
    expect(Mailboxer::Conversation.new).to respond_to(:set_code)

    conversation = create(:user).send_message(create(:user), 'Treść', 'Temat').conversation

    expect(conversation.code).to match(/\A\h{16}\z/)
  end

  it 'extends Mailboxer::Message with the notification creator' do
    expect(Mailboxer::Message.new).to respond_to(:create_notification)
  end
end
