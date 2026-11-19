# frozen_string_literal: true

require 'rails_helper'
require 'rake'

# The task is not scheduled (A.2 in docs/NEW_PRODUCTION_PLAN.md). It raised NameError because it referenced
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
end
