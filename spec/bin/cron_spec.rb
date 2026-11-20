# frozen_string_literal: true

require 'rails_helper'
require 'open3'
require 'timeout'

# bin/cron is the command of the `cron` Kamal role. It must stay idle until CRON_ENABLED=true (cutover).
RSpec.describe 'bin/cron' do
  let(:script) { Rails.root.join('bin/cron').to_s }

  it 'is executable' do
    expect(File.executable?(script)).to be(true)
  end

  it 'starts supercronic with the committed crontab when CRON_ENABLED=true' do
    out, status = Open3.capture2e({ 'CRON_ENABLED' => 'true', 'SUPERCRONIC_BIN' => 'echo' }, script)
    expect(status).to be_success
    expect(out.strip).to eq(Rails.root.join('config/crontab').to_s)
  end

  [nil, 'false', 'yes', ''].each do |value|
    it "idles and never starts supercronic when CRON_ENABLED is #{value.inspect}" do
      env = { 'CRON_ENABLED' => value, 'SUPERCRONIC_BIN' => 'false' }
      out = +''
      pid = nil
      Open3.popen2e(env, script) do |_stdin, output, wait|
        pid = wait.pid
        sleep 1
        expect(wait.alive?).to be(true), 'bin/cron exited instead of idling'
        Process.kill('TERM', pid)
        out << output.read
      end
      expect(out).to include('cron disabled')
    end
  end
end
