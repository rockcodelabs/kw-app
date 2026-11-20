# frozen_string_literal: true

module EmailCenter
  # Verifies the signature Mailgun adds to every Route/webhook request:
  # HMAC-SHA256(signing_key, timestamp + token) as a hex digest.
  # https://documentation.mailgun.com/docs/mailgun/user-manual/webhooks/securing-webhooks
  class MailgunSignature
    MAX_AGE = 1.hour

    def initialize(signing_key:, now: Time.current)
      @signing_key = signing_key.to_s
      @now = now
    end

    def valid?(timestamp:, token:, signature:)
      return false if @signing_key.empty?
      return false if timestamp.blank? || token.blank? || signature.blank?
      return false unless fresh?(timestamp)

      expected = OpenSSL::HMAC.hexdigest('SHA256', @signing_key, "#{timestamp}#{token}")
      ActiveSupport::SecurityUtils.secure_compare(expected, signature.to_s)
    end

    private

    def fresh?(timestamp)
      return false unless timestamp.to_s.match?(/\A\d+\z/)

      (@now.to_i - timestamp.to_i).abs <= MAX_AGE.to_i
    end
  end
end
