# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Healthchecks::Operation::Ping do
  subject(:operation) { described_class.new }

  let(:key) { 'KEY22CHARSKEY22CHARSAB' }
  let(:url) { "https://hc-ping.com/#{key}/kw-prod-send-prepaid-emails" }
  let(:env) { { 'HC_PING_KEY' => key, 'HC_PING_PREFIX' => 'kw-prod' } }

  describe '#call' do
    context 'when the ping is configured' do
      it 'pings <base>/<key>/<prefix>-<job> with underscores turned into dashes' do
        stub = stub_request(:post, url).to_return(status: 200, body: 'OK')

        result = with_env(env) { operation.call(job: :send_prepaid_emails) }

        expect(result).to eq(Dry::Monads::Success(:sent))
        expect(stub).to have_been_requested.once
      end

      it 'pings /fail and sends the message as the body when the status is :fail' do
        stub = stub_request(:post, "#{url}/fail").with(body: 'RuntimeError').to_return(status: 200)

        result = with_env(env) { operation.call(job: :send_prepaid_emails, status: :fail, message: 'RuntimeError') }

        expect(result).to be_success
        expect(stub).to have_been_requested.once
      end

      it 'uses short timeouts so a slow healthchecks.io cannot hang a cron slot' do
        http = instance_double(Net::HTTP, request: Net::HTTPOK.new('1.1', '200', 'OK'))
        allow(Net::HTTP).to receive(:new).and_return(http)
        %i[use_ssl= open_timeout= read_timeout= write_timeout=].each { |setter| allow(http).to receive(setter) }

        with_env(env) { operation.call(job: :send_prepaid_emails) }

        expect(http).to have_received(:open_timeout=).with(3)
        expect(http).to have_received(:read_timeout=).with(5)
      end

      it 'retries once after a network error' do
        stub_request(:post, url).to_timeout.then.to_return(status: 200)

        result = with_env(env) { operation.call(job: :send_prepaid_emails) }

        expect(result).to be_success
        expect(a_request(:post, url)).to have_been_made.twice
      end

      it 'returns a Failure, and never raises, when the network keeps failing' do
        stub_request(:post, url).to_timeout

        result = with_env(env) { operation.call(job: :send_prepaid_emails) }

        expect(result).to be_failure
        expect(result.failure.first).to eq(:request_failed)
        expect(a_request(:post, url)).to have_been_made.twice
      end

      it 'returns a Failure for a non-2xx answer (unknown check)' do
        stub_request(:post, url).to_return(status: 404, body: 'not found')

        result = with_env(env) { operation.call(job: :send_prepaid_emails) }

        expect(result).to eq(Dry::Monads::Failure([:http_error, 404]))
      end

      it 'never writes the ping key to the log' do
        stub_request(:post, url).to_return(status: 500)
        messages = []
        allow(Rails.logger).to receive(:warn) { |message| messages << message.to_s }

        with_env(env) { operation.call(job: :send_prepaid_emails) }

        expect(messages).not_to be_empty
        expect(messages.join).not_to include(key)
      end
    end

    context 'when the configuration has unexpected characters' do
      it 'returns a Failure and makes no request instead of raising a URI error' do
        result = with_env('HC_PING_KEY' => 'bad key/../x', 'HC_PING_PREFIX' => 'kw-prod') do
          operation.call(job: :send_prepaid_emails)
        end

        expect(result).to eq(Dry::Monads::Failure([:invalid_config]))
        expect(a_request(:any, /hc-ping\.com/)).not_to have_been_made
      end
    end

    context 'when the ping is not configured (dev, staging, manual runs)' do
      {
        'no key' => { 'HC_PING_KEY' => nil, 'HC_PING_PREFIX' => 'kw-prod' },
        'no prefix' => { 'HC_PING_KEY' => 'KEY22CHARSKEY22CHARSAB', 'HC_PING_PREFIX' => nil },
        'empty key' => { 'HC_PING_KEY' => '', 'HC_PING_PREFIX' => 'kw-prod' },
        'nothing' => { 'HC_PING_KEY' => nil, 'HC_PING_PREFIX' => nil }
      }.each do |name, values|
        it "does nothing and makes no request with #{name}" do
          result = with_env(values) { operation.call(job: :send_prepaid_emails) }

          expect(result).to eq(Dry::Monads::Success(:skipped))
          expect(a_request(:any, /hc-ping\.com/)).not_to have_been_made
        end
      end
    end
  end
end
