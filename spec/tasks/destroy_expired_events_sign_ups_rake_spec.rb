# frozen_string_literal: true

require 'rails_helper'
require 'rake'

# Scheduled since the club decision of 2026-11-19 (config/crontab, A.2 in docs/NEW_PRODUCTION_PLAN.md) and reports
# to healthchecks.io like every other cron task. It used to raise NameError because it referenced
# Events::Competitions::Worker::DestroyExpiredSignUpWorker; the class is ...::Workers::DestroyExpiredEventSignUpWorker.
RSpec.describe 'destroy_expired_events_sign_ups rake task' do
  let(:worker) { Events::Competitions::Workers::DestroyExpiredEventSignUpWorker }

  before do
    Rails.application.load_tasks unless Rake::Task.task_defined?('destroy_expired_events_sign_ups')
    Rake::Task['destroy_expired_events_sign_ups'].reenable
  end

  it 'enqueues the worker once for every expired event sign-up' do
    allow_any_instance_of(Events::Competitions::Repository)
      .to receive(:expired_sign_ups).and_return([instance_double(Events::Db::SignUpRecord, id: 7), instance_double(Events::Db::SignUpRecord, id: 9)])

    expect(worker).to receive(:perform_async).with(7)
    expect(worker).to receive(:perform_async).with(9)

    Rake::Task['destroy_expired_events_sign_ups'].invoke
  end

  it 'enqueues nothing when no sign-up is expired' do
    allow_any_instance_of(Events::Competitions::Repository).to receive(:expired_sign_ups).and_return([])

    expect(worker).not_to receive(:perform_async)

    Rake::Task['destroy_expired_events_sign_ups'].invoke
  end

  describe 'monitoring' do
    let(:key) { 'KEY22CHARSKEY22CHARSAB' }
    let(:env) { { 'HC_PING_KEY' => key, 'HC_PING_PREFIX' => 'kw-prod' } }
    let(:slug_url) { "https://hc-ping.com/#{key}/kw-prod-destroy-expired-events-sign-ups" }

    before { allow_any_instance_of(Events::Competitions::Repository).to receive(:expired_sign_ups).and_return([]) }

    it 'pings its own check after a successful run' do
      stub = stub_request(:post, slug_url).to_return(status: 200)

      with_env(env) { Rake::Task['destroy_expired_events_sign_ups'].invoke }

      expect(stub).to have_been_requested.once
    end

    it 'pings /fail and still raises when the work fails' do
      allow_any_instance_of(Events::Competitions::Repository).to receive(:expired_sign_ups).and_raise(IOError, 'db down')
      stub = stub_request(:post, "#{slug_url}/fail").to_return(status: 200)

      expect { with_env(env) { Rake::Task['destroy_expired_events_sign_ups'].invoke } }.to raise_error(IOError)
      expect(stub).to have_been_requested.once
    end

    it 'only counts and enqueues nothing with DRY_RUN=1' do
      allow_any_instance_of(Events::Competitions::Repository)
        .to receive(:expired_sign_ups).and_return([instance_double(Events::Db::SignUpRecord, id: 7)])
      expect(worker).not_to receive(:perform_async)

      expect { with_env(env.merge('DRY_RUN' => '1')) { Rake::Task['destroy_expired_events_sign_ups'].invoke } }
        .to output("DRY_RUN destroy_expired_events_sign_ups: count=1\n").to_stdout
    end
  end
end
