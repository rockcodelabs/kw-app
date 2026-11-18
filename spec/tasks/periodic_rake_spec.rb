# frozen_string_literal: true

require 'rails_helper'
require 'rake'

# lib/tasks/periodic.rake is run by supercronic (config/crontab). Every scheduled task reports to
# healthchecks.io through Healthchecks::Monitored, configured by ENV only (HC_PING_KEY, HC_PING_PREFIX).
RSpec.describe 'periodic rake tasks' do
  let(:rake_source) { File.read(Rails.root.join('lib/tasks/periodic.rake')) }
  let(:scheduled_tasks) do
    File.readlines(Rails.root.join('config/crontab'), chomp: true)
        .reject { |line| line.strip.empty? || line.strip.start_with?('#') }
        .flat_map { |line| line.scan(%r{bin/rake (\w+)}).flatten }
  end
  let(:key) { 'KEY22CHARSKEY22CHARSAB' }
  let(:env) { { 'HC_PING_KEY' => key, 'HC_PING_PREFIX' => 'kw-prod' } }

  before do
    Rails.application.load_tasks unless Rake::Task.task_defined?('send_reminders')
    Rake::Task['set_regular_members'].reenable
  end

  def task_body(name)
    rake_source[/^task :#{name} => :environment do\n(.*?)^end$/m, 1]
  end

  describe 'source' do
    it 'wraps every scheduled task in Healthchecks::Monitored with its own name' do
      expect(scheduled_tasks).not_to be_empty
      scheduled_tasks.each do |name|
        expect(task_body(name)).to include("Healthchecks::Monitored.call(:#{name})"), "#{name} is not monitored"
      end
    end

    it 'has no hardcoded healthchecks URL anywhere in the app code' do
      allowed = Rails.root.join('app/components/healthchecks/operation/ping.rb').to_s
      offenders = Dir[Rails.root.join('{app,lib,config}/**/*.{rb,rake,yml,erb}').to_s]
                  .reject { |path| path == allowed }
                  .select { |path| File.read(path).match?(/hc-ping\.com|hchk\.io/) }

      expect(offenders).to be_empty
    end
  end

  describe 'set_regular_members (representative task)' do
    let(:worker) { class_spy(UserManagement::Workers::SetRegularsWorker) }

    before { stub_const('UserManagement::Workers::SetRegularsWorker', worker) }

    it 'pings its check after the work when the ping is configured' do
      stub = stub_request(:post, "https://hc-ping.com/#{key}/kw-prod-set-regular-members").to_return(status: 200)

      with_env(env) { Rake::Task['set_regular_members'].invoke }

      expect(worker).to have_received(:perform_async)
      expect(stub).to have_been_requested.once
    end

    it 'pings /fail and still raises when the work fails' do
      allow(worker).to receive(:perform_async).and_raise(IOError, 'redis down')
      stub = stub_request(:post, "https://hc-ping.com/#{key}/kw-prod-set-regular-members/fail").to_return(status: 200)

      expect { with_env(env) { Rake::Task['set_regular_members'].invoke } }.to raise_error(IOError)
      expect(stub).to have_been_requested.once
    end

    it 'makes no request at all when the ping is not configured' do
      with_env('HC_PING_KEY' => nil, 'HC_PING_PREFIX' => nil) { Rake::Task['set_regular_members'].invoke }

      expect(worker).to have_received(:perform_async)
      expect(a_request(:any, /hc-ping\.com|hchk\.io/)).not_to have_been_made
    end
  end
end
