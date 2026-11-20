# frozen_string_literal: true

module EmailCenter
  # Mailgun Route target for replies to panel mails (reply+<code>@panel.kw.krakow.pl).
  # Griddler parses the request and EmailCenter::Mailman adds the message to the conversation;
  # this controller only refuses requests that Mailgun did not sign.
  class InboundEmailsController < Griddler::EmailsController
    before_action :verify_mailgun_signature

    private

    def verify_mailgun_signature
      signing_key = ENV['MAILGUN_WEBHOOK_SIGNING_KEY']

      if signing_key.blank?
        # 503 (not 403): Mailgun retries non-200 responses, so mail is not lost while the key is missing.
        Rails.logger.error('[inbound mail] MAILGUN_WEBHOOK_SIGNING_KEY is not set, refusing /email_processor')
        return head :service_unavailable
      end

      signature = MailgunSignature.new(signing_key: signing_key)
      return if signature.valid?(timestamp: params[:timestamp], token: params[:token], signature: params[:signature])

      Rails.logger.warn('[inbound mail] invalid Mailgun signature on /email_processor')
      head :forbidden
    end
  end
end
