# frozen_string_literal: true

require 'rails_helper'
require 'rake'

# The weather scrapers (SHMU, TOPR, Meteoblue, Pogodynka) and their pages were deleted on club decision
# (A.2 / A.4 #4 in docs/NEW_PRODUCTION_PLAN.md). Their tables stay in the database, untouched.
RSpec.describe 'removed weather scrapers', type: :routing do
  before { Rails.application.load_tasks unless Rake::Task.task_defined?('send_reminders') }

  it 'has no Scrappers component' do
    expect(Rails.root.join('app/components/scrappers')).not_to exist
    expect(Object.const_defined?(:Scrappers)).to be(false)
  end

  %w[store_shmu store_topr store_weather].each do |name|
    it "has no #{name} rake task" do
      expect(Rake::Task.task_defined?(name)).to be(false)
    end
  end

  %w[/warunki /graphs /api/pogodynka /api/meteoblue].each do |path|
    it "does not route #{path}" do
      expect(get: path).not_to be_routable
    end
  end

  it 'keeps the public blog dashboard route' do
    expect(get: '/api/dashboard').to be_routable
  end

  it 'leaves no scraper leftovers in the scheduler, secrets or rake file' do
    expect(File.read(Rails.root.join('config/schedule.rb'))).not_to match(/store_/)
    expect(File.read(Rails.root.join('config/secrets.yml'))).not_to match(/meteoblue/i)
    expect(File.read(Rails.root.join('config/initializers/secrets_compatibility.rb'))).not_to match(/meteoblue/i)
    expect(File.read(Rails.root.join('lib/tasks/periodic.rake'))).not_to match(/heroku/i)
  end
end
