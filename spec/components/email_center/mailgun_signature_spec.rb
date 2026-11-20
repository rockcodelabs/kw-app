# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmailCenter::MailgunSignature do
  let(:key) { 'test-signing-key' }
  let(:now) { Time.zone.parse('2026-11-21 12:00:00') }
  let(:timestamp) { now.to_i.to_s }
  let(:token) { 'a' * 50 }
  let(:signature) { OpenSSL::HMAC.hexdigest('SHA256', key, "#{timestamp}#{token}") }

  def valid?(signing_key: key, timestamp: self.timestamp, token: self.token, signature: self.signature)
    described_class.new(signing_key: signing_key, now: now)
                   .valid?(timestamp: timestamp, token: token, signature: signature)
  end

  it 'accepts a correct HMAC-SHA256 of timestamp and token' do
    expect(valid?).to be(true)
  end

  it 'rejects a signature made with another key' do
    forged = OpenSSL::HMAC.hexdigest('SHA256', 'other-key', "#{timestamp}#{token}")

    expect(valid?(signature: forged)).to be(false)
  end

  it 'rejects a changed token' do
    expect(valid?(token: 'b' * 50)).to be(false)
  end

  it 'rejects missing parameters' do
    expect(valid?(timestamp: nil)).to be(false)
    expect(valid?(token: nil)).to be(false)
    expect(valid?(signature: nil)).to be(false)
    expect(valid?(signature: '')).to be(false)
  end

  it 'rejects everything when no signing key is configured' do
    expect(valid?(signing_key: nil)).to be(false)
    expect(valid?(signing_key: '')).to be(false)
  end

  it 'rejects a non-numeric timestamp' do
    bad = 'yesterday'
    sig = OpenSSL::HMAC.hexdigest('SHA256', key, "#{bad}#{token}")

    expect(valid?(timestamp: bad, signature: sig)).to be(false)
  end

  it 'rejects a correctly signed but stale timestamp' do
    stale = (now - 2.hours).to_i.to_s
    sig = OpenSSL::HMAC.hexdigest('SHA256', key, "#{stale}#{token}")

    expect(valid?(timestamp: stale, signature: sig)).to be(false)
  end

  it 'tolerates a small clock difference' do
    recent = (now - 10.minutes).to_i.to_s
    sig = OpenSSL::HMAC.hexdigest('SHA256', key, "#{recent}#{token}")

    expect(valid?(timestamp: recent, signature: sig)).to be(true)
  end
end
