# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Strava webhook subscription verification', type: :request do
  let(:path) { '/activities/api/strava_activities/callback' }
  let(:token) { 'spec-verify-token' }

  def with_verify_token(value)
    original = ENV['STRAVA_VERIFY_TOKEN']
    value.nil? ? ENV.delete('STRAVA_VERIFY_TOKEN') : ENV['STRAVA_VERIFY_TOKEN'] = value
    yield
  ensure
    original.nil? ? ENV.delete('STRAVA_VERIFY_TOKEN') : ENV['STRAVA_VERIFY_TOKEN'] = original
  end

  def challenge_params(verify_token)
    { 'hub.mode' => 'subscribe', 'hub.challenge' => 'abc123', 'hub.verify_token' => verify_token }
  end

  context 'when a verify token is configured' do
    around { |ex| with_verify_token(token) { ex.run } }

    it 'echoes the challenge for a matching token' do
      get path, params: challenge_params(token)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['hub.challenge']).to eq('abc123')
    end

    it 'rejects a wrong token' do
      expect { get path, params: challenge_params('strava_token') }.to raise_error(RuntimeError, 'Bad Request')
    end
  end

  context 'when no verify token is configured' do
    around { |ex| with_verify_token(nil) { ex.run } }

    it 'rejects even a blank token (fails closed)' do
      expect { get path, params: challenge_params('') }.to raise_error(RuntimeError, 'Bad Request')
    end
  end
end
