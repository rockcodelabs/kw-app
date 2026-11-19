# frozen_string_literal: true

require 'rails_helper'
require 'open3'
require 'tmpdir'
require 'fileutils'
require 'yaml'

# The logs role (ansible/roles/logs, P7 step 0b, C.10 items 2 and 4 in docs/NEW_PRODUCTION_PLAN.md) keeps a time based
# archive of the container logs on the host: Docker's own rotation is size based, so a busy day could push a quiet
# day out and "the last 7 days" would not be guaranteed. Every night at 00:10 Europe/Warsaw kw-log-archive writes
# yesterday's logs of every app container, the proxy and the accessories into /var/log/kw-app/<name>-YYYYMMDD.log.gz,
# deletes files older than 14 days and sends one healthchecks.io ping.
RSpec.describe 'ansible logs role' do # rubocop:disable RSpec/DescribeClass
  let(:role) { Rails.root.join('ansible/roles/logs') }
  let(:script) { role.join('files/kw-log-archive').to_s }
  let(:tmp) { Pathname.new(Dir.mktmpdir('kw-logs-spec')) }
  let(:stubs) { tmp.join('bin') }
  let(:conf) { tmp.join('env') }
  let(:log_dir) { tmp.join('archive') }
  let(:ping_base) { 'https://hc.example.test' }
  let(:today) { '2026-11-19' }
  let(:ok_url) { "#{ping_base}/abcdefghijklmnopqrstuv/kw-prod-log-archive" }
  # docker ps lists the newest container first. Format: name|service label|role label
  let(:default_containers) do
    "kw-app-web-new111|kw-app-production|web\n" \
      "kw-app-web-old000|kw-app-production|web\n" \
      "kw-app-job-new111|kw-app-production|job\n" \
      "kamal-proxy||\n" \
      "kw-app-postgres||\n" \
      "kw-app-redis||\n" \
      "unrelated-app|other-service|web\n"
  end

  after { FileUtils.remove_entry(tmp) }

  before do
    FileUtils.mkdir_p([stubs, log_dir])
    write_stub('curl', <<~'SH')
      printf 'curl %s\n' "$(printf '%s' "$*" | tr '\n' ' ')" >> "$STUB_LOG"
      exit "${STUB_CURL_RC:-0}"
    SH
    write_stub('docker', <<~'SH')
      echo "docker $*" >> "$STUB_LOG"
      if [ -n "${STUB_DOCKER_BROKEN:-}" ]; then echo "Cannot connect to the Docker daemon" >&2; exit 1; fi
      case "$1" in
        ps)
          printf '%b' "${STUB_CONTAINERS-$STUB_DEFAULT_CONTAINERS}" ;;
        logs)
          name="${*: -1}"
          if [ "$name" = "${STUB_LOGS_FAIL:-}" ]; then echo "Error response from daemon: no such container" >&2; exit 1; fi
          if [ "$name" = "${STUB_LOGS_EMPTY:-}" ]; then exit 0; fi
          echo "2026-11-18T10:00:00.000000000Z stdout line from $name"
          echo "2026-11-18T10:00:01.000000000Z stderr line from $name" >&2 ;;
      esac
    SH
    File.write(conf, <<~ENV)
      HC_PING_KEY='abcdefghijklmnopqrstuv'
      KW_HC_SLUG='kw-prod-log-archive'
      KW_LOG_DIR='#{log_dir}'
      KW_LOG_KEEP_DAYS='14'
      KW_LOG_SERVICE_LABEL='kw-app-production'
      KW_LOG_FIXED='proxy=kamal-proxy postgres=kw-app-postgres redis=kw-app-redis'
      KW_LOG_TZ='Europe/Warsaw'
    ENV
  end

  def write_stub(name, body)
    path = stubs.join(name)
    File.write(path, "#!/usr/bin/env bash\n#{body}")
    FileUtils.chmod(0o755, path)
  end

  def run_script(env: {})
    full_env = {
      'PATH' => "#{stubs}:#{ENV.fetch('PATH')}",
      'KW_LOG_ENV' => conf.to_s,
      'KW_LOG_TODAY' => today,
      'HC_PING_BASE' => ping_base,
      'STUB_LOG' => tmp.join('calls.log').to_s,
      'STUB_DEFAULT_CONTAINERS' => default_containers
    }.merge(env)
    Open3.capture2e(full_env, script)
  end

  def calls
    log = tmp.join('calls.log')
    log.exist? ? log.read.lines.map(&:chomp) : []
  end

  def pings
    calls.grep(/^curl /)
  end

  def archive(name, day = '20261118')
    log_dir.join("#{name}-#{day}.log.gz")
  end

  def unzipped(path)
    out, status = Open3.capture2('zcat', path.to_s)
    raise "zcat failed for #{path}" unless status.success?

    out
  end

  def archive_names
    Dir[log_dir.join('*').to_s].map { |f| File.basename(f) }.sort
  end

  describe 'kw-log-archive' do
    it 'writes yesterday into one gzip per app role and per accessory, and nothing for unrelated containers' do
      out, status = run_script
      expect(status).to be_success, out

      expect(archive_names).to eq(%w[
        job-20261118.log.gz postgres-20261118.log.gz proxy-20261118.log.gz redis-20261118.log.gz web-20261118.log.gz
      ])
    end

    it 'creates the files readable by owner and group only, and leaves no temporary files behind' do
      run_script

      expect(archive('web').stat.mode & 0o777).to eq(0o640)
      expect(Dir.children(log_dir).grep(/\A\./)).to be_empty
    end

    it 'asks Docker for exactly yesterday in Warsaw time, with timestamps' do
      run_script

      web_call = calls.find { |c| c.start_with?('docker logs') && c.end_with?('kw-app-web-new111') }
      expect(web_call).to include('--timestamps')
      expect(web_call).to include('--since 2026-11-18T00:00:00+01:00', '--until 2026-11-19T00:00:00+01:00')
    end

    it 'handles the day the clocks go forward (the window is still midnight to midnight local time)' do
      run_script(env: { 'KW_LOG_TODAY' => '2026-03-30' })

      web_call = calls.find { |c| c.start_with?('docker logs') && c.end_with?('kw-app-web-new111') }
      expect(web_call).to include('--since 2026-03-29T00:00:00+01:00', '--until 2026-03-30T00:00:00+02:00')
      expect(archive('web', '20260329')).to exist
    end

    it 'selects app containers by label and includes stopped ones' do
      run_script

      expect(calls).to include(a_string_matching(/^docker ps .*-a/))
      expect(calls.grep(/^docker logs/).map { |c| c.split.last }).to include('kw-app-web-old000')
      expect(calls.grep(/^docker logs/).map { |c| c.split.last }).not_to include('unrelated-app')
    end

    it 'puts the containers of one role into one file, oldest first, with stderr merged in and a header per container' do
      run_script
      text = unzipped(archive('web'))

      expect(text.index('kw-app-web-old000')).to be < text.index('kw-app-web-new111')
      expect(text).to match(/^## container kw-app-web-old000/)
      expect(text).to include('stdout line from kw-app-web-new111', 'stderr line from kw-app-web-new111')
    end

    it 'still writes the file with a note when a container had no output in the window' do
      run_script(env: { 'STUB_LOGS_EMPTY' => 'kw-app-job-new111' })

      expect(unzipped(archive('job'))).to match(/kw-app-job-new111.*no log lines/)
    end

    it 'sends exactly one success ping when everything worked' do
      out, status = run_script
      expect(status).to be_success, out

      expect(pings.size).to eq(1)
      expect(pings.first).to end_with(" #{ok_url}")
    end

    it 'replaces the file of the same day when it is run twice instead of appending' do
      run_script
      first = unzipped(archive('web'))
      run_script

      expect(unzipped(archive('web'))).to eq(first)
    end

    it 'skips an accessory that does not exist yet without failing' do
      containers = default_containers.sub("kamal-proxy||\n", '')
      out, status = run_script(env: { 'STUB_CONTAINERS' => containers })

      expect(status).to be_success, out
      expect(archive_names).not_to include('proxy-20261118.log.gz')
      expect(pings.first).to end_with(ok_url)
    end

    it 'reports a container whose logs cannot be read, keeps the other files and publishes no half-written file' do
      out, status = run_script(env: { 'STUB_LOGS_FAIL' => 'kw-app-web-old000' })

      expect(status.exitstatus).to eq(1), out
      expect(archive_names).to include('job-20261118.log.gz', 'proxy-20261118.log.gz')
      expect(archive_names).not_to include('web-20261118.log.gz')
      expect(pings.size).to eq(1)
      expect(pings.first).to end_with('/fail')
      expect(pings.first).to include('kw-app-web-old000')
    end

    it 'reports when docker does not answer' do
      out, status = run_script(env: { 'STUB_DOCKER_BROKEN' => '1' })

      expect(status.exitstatus).to eq(1), out
      expect(pings.first).to end_with('/fail')
      expect(pings.first).to match(/docker/i)
      expect(archive_names).to be_empty
    end

    it 'reports when there is not a single container to archive' do
      _out, status = run_script(env: { 'STUB_CONTAINERS' => '' })

      expect(status.exitstatus).to eq(1)
      expect(pings.first).to end_with('/fail')
      expect(pings.first).to match(/no container/i)
    end

    it 'never writes outside the log directory, whatever a label says' do
      containers = "#{default_containers}kw-app-evil-1|kw-app-production|../../evil\n"
      _out, status = run_script(env: { 'STUB_CONTAINERS' => containers })

      expect(status.exitstatus).to eq(1)
      expect(tmp.glob('**/*evil*')).to be_empty
      expect(pings.first).to end_with('/fail')
      expect(archive_names).to include('web-20261118.log.gz')
    end

    describe 'retention' do
      def touch_aged(name, days)
        path = log_dir.join(name)
        File.write(path, 'x')
        time = Time.now - (days * 86_400) - 3600
        File.utime(time, time, path)
        path
      end

      it 'deletes archive files older than 14 days and keeps newer ones' do
        old = touch_aged('web-20261001.log.gz', 15)
        recent = touch_aged('web-20261110.log.gz', 13)

        run_script

        expect(old).not_to exist
        expect(recent).to exist
      end

      it 'only ever deletes files that look like archive files' do
        notes = touch_aged('notes.txt', 400)
        plain_log = touch_aged('restic.log', 400)
        odd = touch_aged('web-latest.log.gz', 400)

        run_script

        expect([notes, plain_log, odd]).to all(exist)
      end

      it 'uses the configured number of days' do
        File.write(conf, "#{conf.read}KW_LOG_KEEP_DAYS='3'\n")
        gone = touch_aged('web-20261101.log.gz', 4)
        kept = touch_aged('web-20261117.log.gz', 2)

        run_script

        expect(gone).not_to exist
        expect(kept).to exist
      end

      it 'still cleans up when the archive step failed, so a broken docker cannot fill the disk' do
        old = touch_aged('web-20261001.log.gz', 20)

        run_script(env: { 'STUB_DOCKER_BROKEN' => '1' })

        expect(old).not_to exist
      end
    end

    it 'exits 0 when only the ping cannot be delivered (healthchecks notices the silence itself)' do
      out, status = run_script(env: { 'STUB_CURL_RC' => '22' })

      expect(status).to be_success, out
      expect(archive('web')).to exist
    end

    it 'retries the ping and uses a timeout' do
      run_script

      expect(pings.first).to match(/-m \d+/)
      expect(pings.first).to match(/--retry \d+/)
    end

    it 'fails loudly, without any ping, when its config file is missing' do
      FileUtils.rm(conf)

      _out, status = run_script

      expect(status.exitstatus).to eq(2)
      expect(pings).to be_empty
    end

    it 'fails loudly when the ping key is missing' do
      File.write(conf, conf.read.sub(/^HC_PING_KEY.*\n/, ''))

      _out, status = run_script

      expect(status.exitstatus).to eq(2)
      expect(pings).to be_empty
    end

    it 'fails loudly when the log directory does not exist' do
      FileUtils.rm_rf(log_dir)

      _out, status = run_script

      expect(status.exitstatus).to eq(2)
      expect(calls.grep(/^docker logs/)).to be_empty
    end

    it 'rejects a non-numeric retention, a malformed date and a malformed container mapping' do
      [
        ["KW_LOG_KEEP_DAYS='many'\n", {}],
        ['', { 'KW_LOG_TODAY' => 'yesterday' }],
        ["KW_LOG_FIXED='proxy=kamal-proxy;rm'\n", {}],
        ["KW_LOG_TZ='Not/AZone'\n", {}]
      ].each do |extra, env|
        File.write(conf, "#{conf.read}#{extra}")
        _out, status = run_script(env: env)

        expect(status.exitstatus).to eq(2), "expected exit 2 for #{extra.inspect} #{env.inspect}"
        File.write(conf, conf.read.sub(extra, ''))
      end
      expect(pings).to be_empty
    end

    it 'never prints the ping key' do
      out, = run_script(env: { 'STUB_DOCKER_BROKEN' => '1' })

      expect(out).not_to include('abcdefghijklmnopqrstuv')
    end
  end

  describe 'role definition' do
    let(:tasks) { role.join('tasks/main.yml').read }
    let(:defaults) { YAML.safe_load(role.join('defaults/main.yml').read) }
    let(:templates) { Dir[role.join('templates/*').to_s].to_h { |path| [File.basename(path), File.read(path)] } }

    it 'is valid YAML' do
      expect { YAML.safe_load(tasks) }.not_to raise_error
      expect(defaults).to be_a(Hash)
    end

    it 'keeps 14 days of the app, proxy and accessory logs under /var/log/kw-app' do
      expect(defaults['logs_dir']).to eq('/var/log/kw-app')
      expect(defaults['logs_keep_days']).to eq(14)
      expect(defaults['logs_service_label']).to eq('kw-app-production')
      expect(defaults['logs_fixed_containers']).to eq(
        'proxy' => 'kamal-proxy', 'postgres' => 'kw-app-postgres', 'redis' => 'kw-app-redis'
      )
      expect(defaults['logs_hc_slug']).to eq('kw-prod-log-archive')
    end

    it 'runs every night at 00:10 Warsaw time and catches up after a reboot, as a hardened oneshot' do
      expect(defaults['logs_run_at']).to eq('00:10:00')
      expect(defaults['logs_tz']).to eq('Europe/Warsaw')
      timer = templates.fetch('kw-log-archive.timer.j2')
      expect(timer).to match(/^OnCalendar=\*-\*-\* \{\{ logs_run_at \}\} \{\{ logs_tz \}\}$/)
      expect(timer).to match(/^Persistent=true$/)
      service = templates.fetch('kw-log-archive.service.j2')
      expect(service).to include('Type=oneshot', 'ExecStart=/usr/local/sbin/kw-log-archive', 'NoNewPrivileges=true')
      expect(service).to match(/^TimeoutStartSec=\d+$/)
    end

    it 'creates the directory root:adm with the setgid bit so every archive file is readable by adm only' do
      block = tasks.split(/^- name:/).find { |task| task.include?('path: "{{ logs_dir }}"') }
      expect(block).to be_present
      expect(block).to match(/owner: root/)
      expect(block).to match(/group: adm/)
      expect(block).to match(/mode: "2750"/)
    end

    it 'writes the env file root-only without logging its content, and reads the ping key from bws' do
      block = tasks.split(/^- name:/).find { |task| task.include?("dest: /etc/kw-log-archive/env\n") }
      expect(block).to be_present
      expect(block).to match(/mode: "0600"/)
      expect(block).to match(/owner: root/)
      expect(block).to match(/no_log: true/)
      expect(tasks).to match(/bws secret get/)
      expect(tasks).to match(/ansible\.builtin\.assert/)
    end

    it 'uses the ping-only healthchecks key, never the API key' do
      expect(defaults['logs_bws_secret_ids']['ping_key']).to eq('d37a01b2-04bd-44d1-8f96-b5060154a055')
      expect(role.join('defaults/main.yml').read).not_to match(/api-key/i)
    end

    it 'rotates only plain .log files with the agreed settings and never copytruncate' do
      logrotate = templates.fetch('logrotate-kw-app.j2')

      expect(logrotate).to include('{{ logs_dir }}/*.log')
      expect(logrotate).to match(/^\s*weekly$/)
      expect(logrotate).to match(/^\s*rotate 8$/)
      expect(logrotate).to match(/^\s*compress$/)
      expect(logrotate).to match(/^\s*delaycompress$/)
      expect(logrotate).to match(/^\s*missingok$/)
      expect(logrotate).to match(/^\s*notifempty$/)
      expect(logrotate).to match(/^\s*create 0640 root adm$/)
      expect(logrotate).not_to match(/copytruncate/)
      expect(tasks).to include('dest: /etc/logrotate.d/kw-app')
    end

    it 'contains no literal secret in defaults, templates or files' do
      all = ([defaults.to_yaml] + templates.values + Dir[role.join('files/*').to_s].map { |f| File.read(f) }).join("\n")

      expect(all).not_to match(/AKIA|api[-_]?key|[0-9a-f]{32}/i)
    end

    it 'is part of the production playbook after monitoring' do
      playbook = YAML.safe_load(Rails.root.join('ansible/playbooks/production.yml').read)
      roles = playbook.first.fetch('roles').map { |r| r.is_a?(Hash) ? r['role'] : r }

      expect(roles).to include('logs')
      expect(roles.index('logs')).to be > roles.index('monitoring')
    end
  end
end
