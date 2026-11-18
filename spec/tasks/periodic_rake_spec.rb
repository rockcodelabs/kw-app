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
        expect(task_body(name)).to match(/Healthchecks::Monitored\.call\(\s*:#{name}\b/), "#{name} is not monitored"
      end
    end

    it 'gives every scheduled task a candidates selector for DRY_RUN=1' do
      scheduled_tasks.each do |name|
        expect(task_body(name)).to match(/Healthchecks::Monitored\.call\(\s*:#{name},\s*candidates:/m), "#{name} has no candidates"
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

  describe 'DRY_RUN=1' do
    before do
      ActiveJob::Base.queue_adapter = :test
      scheduled_tasks.each { |name| Rake::Task[name].reenable }
      Rake::Task['cron:dry_run'].reenable
    end

    let!(:long_unpaid_reservation) do
      create(:reservation, end_date: 30.days.ago.to_date).tap do |record|
        record.update_column(:created_at, 5.days.ago)
        create(:payment, payable: record)
      end
    end
    let!(:ended_yesterday) { create(:reservation, end_date: 1.day.ago.to_date) }
    let!(:outdated_profile) do
      create(:profile).tap do |record|
        record.update_columns(accepted: false, created_at: 5.months.ago)
        create(:payment, payable: record)
      end
    end
    let!(:regular_candidate) do
      create(:profile, position: ['candidate'], application_date: 2.years.ago.to_date)
    end

    def capture_stdout
      original = $stdout
      $stdout = StringIO.new
      yield
      $stdout.string
    ensure
      $stdout = original
    end

    def dry_run_env
      env.merge('DRY_RUN' => '1')
    end

    it 'prints one count line per scheduled task and changes nothing' do
      expect_any_instance_of(Sidekiq::Client).not_to receive(:push)
      reservations = Db::Reservation.count
      profiles = Db::Profile.count

      scheduled_tasks.each do |name|
        output = with_env(dry_run_env) { capture_stdout { Rake::Task[name].invoke } }

        expect(output).to match(/\ADRY_RUN #{name}: \w+=\d+( \w+=\d+)*\n\z/), "#{name} printed #{output.inspect}"
      end

      expect(ActiveJob::Base.queue_adapter.enqueued_jobs).to be_empty
      expect(Db::Reservation.count).to eq(reservations)
      expect(Db::Profile.count).to eq(profiles)
      expect(regular_candidate.reload.position).to eq(['candidate'])
      expect(a_request(:any, /hc-ping\.com|hchk\.io/)).not_to have_been_made
    end

    it 'reports what the real run would process' do
      counts = scheduled_tasks.to_h do |name|
        [name, with_env(dry_run_env) { capture_stdout { Rake::Task[name].invoke } }]
      end

      expect(counts['send_reminders']).to include('count=1')
      expect(counts['destroy_unpaid_reservations']).to include('count=1')
      expect(counts['destroy_outdated_profiles']).to include('count=1')
      expect(counts['set_regular_members']).to include('count=1')
      expect(counts['recalculate_cost']).to include('count=1')
    end

    it 'prints no ids, e-mails or names' do
      output = with_env(dry_run_env) { capture_stdout { scheduled_tasks.each { |name| Rake::Task[name].invoke } } }

      expect(output).not_to include(outdated_profile.email, regular_candidate.email, outdated_profile.last_name)
    end

    describe 'cron:dry_run' do
      it 'reports every scheduled task once, in crontab order, and leaves ENV[DRY_RUN] as it was' do
        output = with_env(env.merge('DRY_RUN' => nil)) do
          capture_stdout { Rake::Task['cron:dry_run'].invoke }
        end

        expect(output.lines.map { |line| line[/\ADRY_RUN (\w+):/, 1] }).to eq(scheduled_tasks.uniq)
        expect(ENV.fetch('DRY_RUN', nil)).to be_nil
        expect(ActiveJob::Base.queue_adapter.enqueued_jobs).to be_empty
      end
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
