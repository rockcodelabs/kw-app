# frozen_string_literal: true

require 'net/http'

module Healthchecks
  module Operation
    # Reports one run of a job to healthchecks.io: <base>/<HC_PING_KEY>/<HC_PING_PREFIX>-<job>[/fail].
    #
    # Configured by ENV only and with NO defaults: when HC_PING_KEY or HC_PING_PREFIX is missing it does
    # nothing, so dev, staging and manual runs can never ping production checks. It never raises, because a
    # monitoring problem must not break the job that is being monitored. The URL contains the ping key and
    # is therefore never logged.
    class Ping
      include Dry::Monads[:result]

      BASE_URL = 'https://hc-ping.com'
      OPEN_TIMEOUT = 3
      READ_TIMEOUT = 5
      ATTEMPTS = 2
      SAFE_ENV_VALUE = /\A[A-Za-z0-9_-]+\z/
      NETWORK_ERRORS = [
        Timeout::Error, SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError, Net::ProtocolError
      ].freeze

      def call(job:, status: :ok, message: nil)
        key = ENV['HC_PING_KEY'].to_s
        prefix = ENV['HC_PING_PREFIX'].to_s
        return Success(:skipped) if key.empty? || prefix.empty?

        unless key.match?(SAFE_ENV_VALUE) && prefix.match?(SAFE_ENV_VALUE)
          Rails.logger.warn('[healthchecks] HC_PING_KEY / HC_PING_PREFIX have unexpected characters, ping skipped')
          return Failure([:invalid_config])
        end

        post(uri_for(key, prefix, job, status), message.to_s)
      end

      private

      def uri_for(key, prefix, job, status)
        slug = "#{prefix}-#{job.to_s.tr('_', '-')}"
        URI("#{BASE_URL}/#{key}/#{slug}#{'/fail' if status == :fail}")
      end

      def post(uri, body)
        attempts = 0
        begin
          attempts += 1
          response = request(uri, body)
        rescue *NETWORK_ERRORS => e
          retry if attempts < ATTEMPTS
          Rails.logger.warn("[healthchecks] ping failed: #{e.class}")
          return Failure([:request_failed, e.class.name])
        end

        return Success(:sent) if response.is_a?(Net::HTTPSuccess)

        Rails.logger.warn("[healthchecks] ping rejected: HTTP #{response.code}")
        Failure([:http_error, response.code.to_i])
      end

      def request(uri, body)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.open_timeout = OPEN_TIMEOUT
        http.read_timeout = READ_TIMEOUT
        http.write_timeout = READ_TIMEOUT
        http.request(Net::HTTP::Post.new(uri, 'Content-Type' => 'text/plain').tap { |req| req.body = body })
      end
    end
  end
end
