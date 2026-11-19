# frozen_string_literal: true

require 'rails_helper'
require 'yaml'

# G43 in docs/NEW_PRODUCTION_PLAN.md: Redis on new prod logged "Memory overcommit must be enabled!". With
# vm.overcommit_memory = 0 the fork for a background save can fail under memory pressure, Redis then stops
# persisting and refuses writes (MISCONF), which would stop Sidekiq from enqueueing jobs.
RSpec.describe 'ansible kernel role sysctl files' do # rubocop:disable RSpec/DescribeClass
  let(:role) { Rails.root.join('ansible/roles/kernel') }
  let(:tasks) { YAML.safe_load(role.join('tasks/main.yml').read) }
  let(:settings) do
    Dir[role.join('files/*.conf').to_s].each_with_object(Hash.new { |h, k| h[k] = [] }) do |path, found|
      File.readlines(path).each do |line|
        match = line.strip.match(/\A([a-z0-9_.]+)\s*=\s*(\S+)\z/)
        found[match[1]] << [File.basename(path), match[2]] if match
      end
    end
  end

  it 'turns memory overcommit on for Redis, in its own file, exactly once' do
    expect(settings['vm.overcommit_memory']).to eq([['92-redis.conf', '1']])
  end

  it 'installs that file together with the other sysctl files and reloads sysctl' do
    task = tasks.find { |t| t['name'] == 'Sysctl hardening files' }

    expect(task['loop']).to include('90-hardening.conf', '91-lynis.conf', '92-redis.conf')
    expect(task['notify']).to eq('Reload sysctl')
  end

  it 'keeps the existing hardening values untouched' do
    expect(settings['vm.swappiness']).to eq([['90-hardening.conf', '10']])
    expect(settings['kernel.sysrq']).to eq([['91-lynis.conf', '0']])
  end
end
