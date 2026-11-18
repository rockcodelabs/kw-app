# frozen_string_literal: true

require 'rails_helper'
require 'rake'

# config/crontab is run by supercronic in the `cron` Kamal role (config/deploy.production.yml, bin/cron).
RSpec.describe 'config/crontab' do
  let(:crontab_path) { Rails.root.join('config/crontab') }
  let(:entries) do
    File.readlines(crontab_path, chomp: true)
        .reject { |line| line.strip.empty? || line.strip.start_with?('#') }
        .map { |line| line.split(/\s+/, 6) }
  end
  let(:tasks) { entries.flat_map { |entry| entry.last.scan(%r{bin/rake (\w+)}).flatten } }

  before do
    Rails.application.load_tasks unless Rake::Task.task_defined?('send_reminders')
  end

  it 'has entries with a five-field schedule and a command' do
    expect(entries).not_to be_empty
    entries.each do |minute, hour, day, month, weekday, command|
      expect([minute, hour, day, month, weekday]).to all(match(%r{\A[\d*/,-]+\z}))
      expect(command).to start_with('bin/rake ')
    end
  end

  it 'only runs rake tasks that exist' do
    tasks.each do |task|
      expect(Rake::Task.task_defined?(task)).to be(true), "no rake task #{task}"
    end
  end

  it 'runs every task that config/schedule.rb schedules, and nothing else' do
    scheduled = File.readlines(Rails.root.join('config/schedule.rb'))
                    .reject { |line| line.strip.start_with?('#') }
                    .flat_map { |line| line.scan(/rake :(\w+)/).flatten }
    expect(tasks).to match_array(scheduled)
  end

  it 'chains the tasks of one slot on a single line so they run one after another' do
    half_hourly = entries.find { |entry| entry[1] == '8-23' }
    expect(half_hourly.last.split(';').map { |part| part.strip }).to eq(
      ['bin/rake send_prepaid_emails', 'bin/rake destroy_expired_sign_ups', 'bin/rake fill_empty_places']
    )
  end

  it 'runs set_regular_members weekly, on Mondays' do
    entry = entries.find { |e| e.last.include?('set_regular_members') }
    expect(entry[4]).to eq('1')
  end
end
