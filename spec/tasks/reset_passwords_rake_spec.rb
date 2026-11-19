# frozen_string_literal: true

require 'rails_helper'
require 'rake'

# `rake reset_passwords` mails a reset link to EVERY user, so it needs an explicit CONFIRM=yes.
RSpec.describe 'reset_passwords rake task' do
  before do
    Rails.application.load_tasks unless Rake::Task.task_defined?('reset_passwords')
    Rake::Task['reset_passwords'].reenable
    create_list(:user, 2)
  end

  it 'aborts without sending anything when CONFIRM=yes is missing' do
    expect_any_instance_of(Db::User).not_to receive(:send_reset_password_instructions)

    expect { with_env('CONFIRM' => nil) { Rake::Task['reset_passwords'].invoke } }
      .to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
      .and output(/CONFIRM=yes/).to_stderr
  end

  it 'aborts for any other CONFIRM value' do
    expect_any_instance_of(Db::User).not_to receive(:send_reset_password_instructions)

    expect { with_env('CONFIRM' => 'true') { Rake::Task['reset_passwords'].invoke } }
      .to raise_error(SystemExit).and output(/CONFIRM=yes/).to_stderr
  end

  it 'sends a reset mail to every user with CONFIRM=yes' do
    notified = []
    allow_any_instance_of(Db::User).to receive(:send_reset_password_instructions) { |user| notified << user.id }

    with_env('CONFIRM' => 'yes') { Rake::Task['reset_passwords'].invoke }

    expect(notified).to match_array(Db::User.pluck(:id))
    expect(notified.size).to be >= 2
  end
end
