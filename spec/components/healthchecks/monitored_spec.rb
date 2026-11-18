# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Healthchecks::Monitored do
  let(:ping) { instance_spy(Healthchecks::Operation::Ping, call: Dry::Monads::Success(:sent)) }

  describe '.call' do
    it 'runs the block, pings OK afterwards and returns the block result' do
      ran = false

      result = described_class.call(:send_reminders, ping: ping) { ran = true; :done }

      expect(result).to eq(:done)
      expect(ran).to be(true)
      expect(ping).to have_received(:call).with(job: :send_reminders, status: :ok).once
    end

    it 'does not ping OK before the work is finished' do
      order = []
      allow(ping).to receive(:call) { order << :ping }

      described_class.call(:send_reminders, ping: ping) { order << :work }

      expect(order).to eq(%i[work ping])
    end

    it 'pings /fail with the error class (no message, it may hold personal data) and re-raises' do
      expect do
        described_class.call(:send_reminders, ping: ping) { raise ArgumentError, 'secret member@example.com' }
      end.to raise_error(ArgumentError)

      expect(ping).to have_received(:call).with(job: :send_reminders, status: :fail, message: 'ArgumentError').once
      expect(ping).not_to have_received(:call).with(hash_including(status: :ok))
    end

    it 'does not fail the job when the ping itself fails' do
      allow(ping).to receive(:call).and_return(Dry::Monads::Failure([:request_failed, 'Net::ReadTimeout']))

      expect(described_class.call(:send_reminders, ping: ping) { :done }).to eq(:done)
    end

    it 'does not hide the original error when the fail ping fails too' do
      allow(ping).to receive(:call).and_return(Dry::Monads::Failure([:request_failed, 'Net::ReadTimeout']))

      expect { described_class.call(:send_reminders, ping: ping) { raise KeyError, 'boom' } }
        .to raise_error(KeyError, 'boom')
    end
  end
end
