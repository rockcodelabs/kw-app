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

    it 'does not evaluate candidates in a normal run' do
      candidates = -> { raise 'must not be called' }

      expect(described_class.call(:send_reminders, ping: ping, candidates: candidates, dry_run: false) { :done })
        .to eq(:done)
    end
  end

  # DRY_RUN=1 reports what a task WOULD process (counts only, no ids or e-mails: they are personal data)
  # and does nothing else: no work, no enqueue, no mail, no ping.
  describe '.call in dry-run mode' do
    it 'does not run the block and does not ping' do
      ran = false

      expect do
        described_class.call(:send_reminders, ping: ping, candidates: -> { 3 }, dry_run: true) { ran = true }
      end.to output("DRY_RUN send_reminders: count=3\n").to_stdout

      expect(ran).to be(false)
      expect(ping).not_to have_received(:call)
    end

    it 'prints a hash of counts as label=count pairs and returns it' do
      result = nil

      expect do
        result = described_class.call(:destroy_expired_sign_ups, ping: ping, dry_run: true,
                                                                  candidates: -> { { training: 1, business: 0 } }) { :work }
      end.to output("DRY_RUN destroy_expired_sign_ups: training=1 business=0\n").to_stdout

      expect(result).to eq(training: 1, business: 0)
    end

    it 'refuses to run a task that has no candidates selector, and still does not run the work' do
      ran = false

      expect do
        described_class.call(:send_reminders, ping: ping, dry_run: true) { ran = true }
      end.to raise_error(ArgumentError, /candidates/)

      expect(ran).to be(false)
      expect(ping).not_to have_received(:call)
    end

    it 'does not ping when the selector itself raises' do
      expect do
        described_class.call(:send_reminders, ping: ping, dry_run: true, candidates: -> { raise IOError, 'db down' }) { :work }
      end.to raise_error(IOError)

      expect(ping).not_to have_received(:call)
    end

    describe 'switch from ENV[DRY_RUN]' do
      def run_with(value)
        ran = false
        with_env('DRY_RUN' => value) do
          expect { described_class.call(:send_reminders, ping: ping, candidates: -> { 0 }) { ran = true } }
            .to output(/.*/).to_stdout
        end
        ran
      end

      it 'is on for 1 and true' do
        expect(run_with('1')).to be(false)
        expect(run_with('true')).to be(false)
      end

      it 'is off when unset, empty, 0 or false' do
        [nil, '', '0', 'false'].each do |value|
          ran = false
          with_env('DRY_RUN' => value) { described_class.call(:send_reminders, ping: ping) { ran = true } }
          expect(ran).to be(true), "DRY_RUN=#{value.inspect} must not enable the dry run"
        end
      end
    end
  end
end
