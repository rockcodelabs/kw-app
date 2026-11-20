# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /email_processor (Mailgun inbound route)', type: :request do
  let(:signing_key) { 'test-signing-key' }
  let(:author) { create(:user) }
  let(:member) { create(:user) }
  let(:conversation) { author.send_message(member, 'Treść', 'Temat').conversation }
  let(:token) { 'b' * 50 }
  let(:timestamp) { Time.current.to_i.to_s }
  let(:signature) { OpenSSL::HMAC.hexdigest('SHA256', signing_key.to_s, "#{timestamp}#{token}") }
  let(:reply_text) { 'Dziękuję, będę na miejscu.' }
  let(:mailgun_params) do
    {
      'recipient' => "reply+#{conversation.code}@panel.kw.krakow.pl",
      'sender' => member.email,
      'From' => "#{member.first_name} <#{member.email}>",
      'To' => "Panel KW Kraków <reply+#{conversation.code}@panel.kw.krakow.pl>",
      'subject' => 'Re: Temat',
      'body-plain' => "#{reply_text}\n\n-- ODPOWIEDZ E-MAILOWO POWYŻEJ TEJ LINI --\nstary cytat",
      'stripped-text' => reply_text,
      'timestamp' => timestamp,
      'token' => token,
      'signature' => signature
    }
  end

  around do |example|
    original = ActionMailer::Base.default_url_options
    ActionMailer::Base.default_url_options = { host: 'panel.example.com' }
    example.run
  ensure
    ActionMailer::Base.default_url_options = original
  end

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('MAILGUN_WEBHOOK_SIGNING_KEY').and_return(signing_key)
    conversation
  end

  it 'routes to the signed inbound controller' do
    expect(Rails.application.routes.recognize_path('/email_processor', method: :post))
      .to include(controller: 'email_center/inbound_emails', action: 'create')
  end

  it 'uses the Mailgun adapter for Griddler' do
    expect(Griddler.configuration.email_service).to eq(Griddler::Mailgun::Adapter)
  end

  context 'with a valid signature' do
    it 'adds the reply to the conversation as the sender' do
      expect { post '/email_processor', params: mailgun_params }
        .to change { conversation.reload.messages.count }.from(1).to(2)

      expect(response).to have_http_status(:ok)
      message = conversation.messages.order(:id).last
      expect(message.sender).to eq(member)
      expect(message.body).to include(reply_text)
      expect(message.body).not_to include('stary cytat')
    end

    it 'ignores mail from an unknown sender' do
      params = mailgun_params.merge('From' => 'stranger@example.com', 'sender' => 'stranger@example.com')

      expect { post '/email_processor', params: params }.not_to(change { Mailboxer::Message.count })
      expect(response).to have_http_status(:ok)
    end

    it 'ignores mail that is not addressed to the panel host' do
      params = mailgun_params.merge('To' => 'someone@example.com', 'recipient' => 'someone@example.com')

      expect { post '/email_processor', params: params }.not_to(change { Mailboxer::Message.count })
      expect(response).to have_http_status(:ok)
    end

    it 'ignores mail for an unknown conversation code' do
      params = mailgun_params.merge('To' => 'reply+0000000000000000@panel.kw.krakow.pl')

      expect { post '/email_processor', params: params }.not_to(change { Mailboxer::Message.count })
      expect(response).to have_http_status(:ok)
    end
  end

  context 'with a forged signature' do
    let(:signature) { OpenSSL::HMAC.hexdigest('SHA256', 'attacker-key', "#{timestamp}#{token}") }

    it 'rejects the request and creates nothing' do
      expect { post '/email_processor', params: mailgun_params }.not_to(change { Mailboxer::Message.count })

      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'without signature parameters' do
    it 'rejects the request (the old unauthenticated behaviour)' do
      params = mailgun_params.except('timestamp', 'token', 'signature')

      expect { post '/email_processor', params: params }.not_to(change { Mailboxer::Message.count })

      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'when no signing key is configured' do
    let(:signing_key) { nil }

    it 'fails closed with 503 so Mailgun retries later' do
      allow(ENV).to receive(:[]).with('MAILGUN_WEBHOOK_SIGNING_KEY').and_return(nil)

      expect { post '/email_processor', params: mailgun_params }.not_to(change { Mailboxer::Message.count })

      expect(response).to have_http_status(:service_unavailable)
    end
  end
end
