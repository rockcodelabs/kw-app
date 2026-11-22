# frozen_string_literal: true

require 'rails_helper'
require 'open3'
require 'tmpdir'
require 'fileutils'
require 'yaml'

# The monitoring role (ansible/roles/monitoring, P6-B in docs/NEW_PRODUCTION_PLAN.md) is the host's self-check:
# every 10 minutes one script looks at disk, memory, swap, containers and failed units and sends exactly one
# healthchecks.io ping. Success ping = healthy, /fail with the problems as body = a problem, silence = dead host.
RSpec.describe 'ansible monitoring role' do # rubocop:disable RSpec/DescribeClass
  let(:role) { Rails.root.join('ansible/roles/monitoring') }
  let(:script) { role.join('files/kw-host-check').to_s }
  let(:tmp) { Pathname.new(Dir.mktmpdir('kw-monitoring-spec')) }
  let(:stubs) { tmp.join('bin') }
  let(:conf) { tmp.join('env') }
  let(:ping_base) { 'https://hc.example.test' }

  after { FileUtils.remove_entry(tmp) }

  before do
    FileUtils.mkdir_p(stubs)
    write_stub('curl', <<~'SH')
      printf 'curl %s\n' "$(printf '%s' "$*" | tr '\n' ' ')" >> "$STUB_LOG"
      exit "${STUB_CURL_RC:-0}"
    SH
    write_stub('df', <<~'SH')
      if [ "$1" = "-Pi" ]; then pct="${STUB_INODE_PCT:-3}"; else pct="${STUB_DISK_PCT:-16}"; fi
      if [ -n "${STUB_DF_BROKEN:-}" ]; then exit 1; fi
      printf 'Filesystem 1024-blocks Used Available Capacity Mounted on\n'
      printf '/dev/sda1 39000000 6000000 33000000 %s%% /\n' "$pct"
    SH
    write_stub('free', <<~'SH')
      printf '               total        used        free      shared  buff/cache   available\n'
      printf 'Mem:            3814         761         997         158        2482        %s\n' "${STUB_MEM_AVAILABLE:-3053}"
      printf 'Swap:           2048        %s        %s\n' "${STUB_SWAP_USED:-0}" "$((2048 - ${STUB_SWAP_USED:-0}))"
    SH
    write_stub('docker', <<~'SH')
      echo "docker $*" >> "$STUB_LOG"
      if [ -n "${STUB_DOCKER_BROKEN:-}" ]; then echo "Cannot connect to the Docker daemon" >&2; exit 1; fi
      printf '%b' "${STUB_CONTAINERS:-kw-app-redis|running|Up 13 hours\nkw-app-postgres|running|Up 13 hours\n}"
    SH
    write_stub('systemctl', <<~'SH')
      echo "systemctl $*" >> "$STUB_LOG"
      printf '%b' "${STUB_FAILED_UNITS:-}"
    SH
    write_stub('openssl', <<~'SH')
      echo "openssl $*" >> "$STUB_LOG"
      case "$1" in
        s_client)
          if [ -n "${STUB_TLS_BROKEN:-}" ]; then exit 1; fi
          printf -- '-----BEGIN CERTIFICATE-----\nstub\n-----END CERTIFICATE-----\n' ;;
        x509)
          case "$*" in
            *-checkend*) cat > /dev/null; exit "${STUB_TLS_CHECKEND_RC:-0}" ;;
            *-enddate*) cat > /dev/null; echo 'notAfter=Feb 17 10:00:00 2027 GMT' ;;
            *) cat ;;
          esac ;;
      esac
    SH
    File.write(conf, <<~ENV)
      HC_PING_KEY='abcdefghijklmnopqrstuv'
      KW_HC_SLUG='kw-prod-host-health'
      KW_EXPECTED_CONTAINERS='kw-app-postgres kw-app-redis'
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
      'KW_HOST_ENV' => conf.to_s,
      'HC_PING_BASE' => ping_base,
      'STUB_LOG' => tmp.join('calls.log').to_s
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

  def ok_url
    "#{ping_base}/abcdefghijklmnopqrstuv/kw-prod-host-health"
  end

  describe 'kw-host-check' do
    it 'sends exactly one success ping when everything is fine' do
      out, status = run_script
      expect(status).to be_success, out

      expect(pings.size).to eq(1)
      expect(pings.first).to end_with(" #{ok_url}")
      expect(pings.first).not_to include('/fail')
    end

    it 'sends /fail with the reason when the disk is full, and still exits 0' do
      out, status = run_script(env: { 'STUB_DISK_PCT' => '85' })
      expect(status).to be_success, out

      expect(pings.size).to eq(1)
      expect(pings.first).to end_with(" #{ok_url}/fail")
      expect(pings.first).to match(/--data-raw .*disk.*85%/m)
    end

    it 'alerts exactly at the limit and not below it' do
      run_script(env: { 'STUB_DISK_PCT' => '79' })
      expect(pings.last).not_to include('/fail')

      FileUtils.rm_f(tmp.join('calls.log'))
      run_script(env: { 'STUB_DISK_PCT' => '80' })
      expect(pings.last).to end_with('/fail')
    end

    it 'alerts when inodes run out' do
      run_script(env: { 'STUB_INODE_PCT' => '90' })

      expect(pings.first).to end_with('/fail')
      expect(pings.first).to match(/inode/i)
    end

    it 'alerts when little memory is available' do
      run_script(env: { 'STUB_MEM_AVAILABLE' => '200' })

      expect(pings.first).to end_with('/fail')
      expect(pings.first).to match(/memory/i)
    end

    it 'does not alert just above 8 percent available memory but alerts below it' do
      run_script(env: { 'STUB_MEM_AVAILABLE' => '310' })
      expect(pings.last).to end_with(ok_url)

      FileUtils.rm_f(tmp.join('calls.log'))
      run_script(env: { 'STUB_MEM_AVAILABLE' => '300' })
      expect(pings.last).to end_with('/fail')
    end

    it 'alerts when swap is more than half used' do
      run_script(env: { 'STUB_SWAP_USED' => '1500' })

      expect(pings.first).to end_with('/fail')
      expect(pings.first).to match(/swap/i)
    end

    it 'tolerates a host with no swap at all' do
      write_stub('free', <<~'SH')
        printf '               total        used        free      shared  buff/cache   available\n'
        printf 'Mem:            3814         761         997         158        2482        3053\n'
        printf 'Swap:              0           0           0\n'
      SH

      out, status = run_script
      expect(status).to be_success, out
      expect(pings.first).to end_with(ok_url)
    end

    it 'alerts when an expected container is not running' do
      containers = "kw-app-postgres|running|Up 1 hour\nkw-app-redis|exited|Exited (1) 2 minutes ago\n"
      run_script(env: { 'STUB_CONTAINERS' => containers })

      expect(pings.first).to end_with('/fail')
      expect(pings.first).to match(/kw-app-redis/)
      expect(pings.first).not_to match(/kw-app-postgres/)
    end

    it 'alerts when an expected container is missing entirely' do
      run_script(env: { 'STUB_CONTAINERS' => "kw-app-postgres|running|Up 1 hour\n" })

      expect(pings.first).to end_with('/fail')
      expect(pings.first).to match(/kw-app-redis/)
    end

    it 'matches Kamal versioned container names by prefix and ignores retained old ones' do
      File.write(conf, "#{conf.read}KW_EXPECTED_CONTAINERS='kw-app-postgres kw-app-web'\n")
      containers = "kw-app-postgres|running|Up 1 hour\n" \
                   "kw-app-web-abc123|running|Up 5 minutes\n" \
                   "kw-app-web-old999|exited|Exited (0) 2 days ago\n"

      out, status = run_script(env: { 'STUB_CONTAINERS' => containers })

      expect(status).to be_success, out
      expect(pings.first).to end_with(ok_url)
    end

    it 'does not let a prefix match a different container (kw-app-web must not match kw-app-webhook)' do
      File.write(conf, "#{conf.read}KW_EXPECTED_CONTAINERS='kw-app-web'\n")

      run_script(env: { 'STUB_CONTAINERS' => "kw-app-webhook|running|Up 1 hour\n" })

      expect(pings.first).to end_with('/fail')
    end

    it 'alerts when any container is restarting or unhealthy' do
      containers = "kw-app-postgres|running|Up 1 hour\nkw-app-redis|running|Up 1 hour\n" \
                   "kw-app-job-abc|restarting|Restarting (1) 5 seconds ago\n" \
                   "kw-app-web-abc|running|Up 2 hours (unhealthy)\n"
      run_script(env: { 'STUB_CONTAINERS' => containers })

      expect(pings.first).to end_with('/fail')
      expect(pings.first).to match(/kw-app-job-abc/)
      expect(pings.first).to match(/kw-app-web-abc/)
    end

    it 'alerts when docker does not answer' do
      run_script(env: { 'STUB_DOCKER_BROKEN' => '1' })

      expect(pings.first).to end_with('/fail')
      expect(pings.first).to match(/docker/i)
    end

    it 'alerts on failed systemd units and names them' do
      run_script(env: { 'STUB_FAILED_UNITS' => "kw-backup.service loaded failed failed Nightly dump\n" })

      expect(pings.first).to end_with('/fail')
      expect(pings.first).to match(/kw-backup\.service/)
      expect(calls).to include('systemctl --failed --no-legend --plain')
    end

    it 'alerts when it cannot read the disk numbers instead of staying silent' do
      run_script(env: { 'STUB_DF_BROKEN' => '1' })

      expect(pings.first).to end_with('/fail')
    end

    it 'reports every problem in one ping' do
      run_script(env: { 'STUB_DISK_PCT' => '95', 'STUB_SWAP_USED' => '2000' })

      expect(pings.size).to eq(1)
      expect(pings.first).to match(/disk/i)
      expect(pings.first).to match(/swap/i)
    end

    it 'exits 0 even when the ping cannot be delivered (the problem is logged, not a failed unit)' do
      out, status = run_script(env: { 'STUB_DISK_PCT' => '95', 'STUB_CURL_RC' => '22' })

      expect(status).to be_success, out
      expect(out).to match(/disk/i)
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
      File.write(conf, "KW_HC_SLUG='kw-prod-host-health'\n")

      _out, status = run_script

      expect(status.exitstatus).to eq(2)
      expect(pings).to be_empty
    end

    it 'rejects a non-numeric threshold instead of silently disabling the check' do
      File.write(conf, "#{conf.read}KW_DISK_MAX_PCT='lots'\n")

      _out, status = run_script

      expect(status.exitstatus).to eq(2)
      expect(pings).to be_empty
    end

    it 'never prints the ping key' do
      out, = run_script(env: { 'STUB_DISK_PCT' => '95' })

      expect(out).not_to include('abcdefghijklmnopqrstuv')
    end

    # G42: kamal-proxy renews the Let's Encrypt certificate by itself, but nothing told anyone when that fails.
    describe 'certificate expiry check' do
      let(:tls_conf) { "KW_TLS_CHECK_HOST='panel.kw.krakow.pl'\nKW_TLS_MIN_DAYS='21'\n" }

      def enable_tls_check(extra = '')
        File.write(conf, "#{conf.read}#{tls_conf}#{extra}")
      end

      it 'does not look at any certificate while the check is off (before the DNS flip)' do
        out, status = run_script

        expect(status).to be_success, out
        expect(calls.grep(/^openssl/)).to be_empty
        expect(pings.first).to end_with(ok_url)
      end

      it 'asks the local proxy for the certificate of the configured host and stays green when it is valid' do
        enable_tls_check

        out, status = run_script

        expect(status).to be_success, out
        expect(calls).to include(a_string_matching(/^openssl s_client .*-connect 127\.0\.0\.1:443 .*-servername panel\.kw\.krakow\.pl/))
        expect(calls).to include(a_string_matching(/^openssl x509 .*-checkend 1814400/))
        expect(pings.size).to eq(1)
        expect(pings.first).to end_with(ok_url)
      end

      it 'sends /fail naming the host, the limit and the expiry date when the certificate expires too soon' do
        enable_tls_check

        run_script(env: { 'STUB_TLS_CHECKEND_RC' => '1' })

        expect(pings.size).to eq(1)
        expect(pings.first).to end_with('/fail')
        expect(pings.first).to match(/certificate/i)
        expect(pings.first).to include('panel.kw.krakow.pl', '21 days', 'Feb 17 10:00:00 2027 GMT')
      end

      it 'sends /fail when no certificate is served at all' do
        enable_tls_check

        run_script(env: { 'STUB_TLS_BROKEN' => '1' })

        expect(pings.first).to end_with('/fail')
        expect(pings.first).to match(/certificate.*panel\.kw\.krakow\.pl/i)
      end

      it 'uses the configured address and day limit' do
        enable_tls_check("KW_TLS_ADDR='127.0.0.1:8443'\nKW_TLS_MIN_DAYS='10'\n")

        run_script

        expect(calls).to include(a_string_matching(/-connect 127\.0\.0\.1:8443 /))
        expect(calls).to include(a_string_matching(/-checkend 864000/))
      end

      it 'rejects a malformed host or day limit instead of silently skipping the check' do
        enable_tls_check("KW_TLS_CHECK_HOST='panel kw;rm'\n")
        _out, status = run_script
        expect(status.exitstatus).to eq(2)
        expect(pings).to be_empty

        File.write(conf, "#{conf.read}KW_TLS_CHECK_HOST='panel.kw.krakow.pl'\nKW_TLS_MIN_DAYS='soon'\n")
        _out, status = run_script
        expect(status.exitstatus).to eq(2)
        expect(pings).to be_empty
      end
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

    it 'watches the database, redis, the three app roles and the proxy' do
      expect(defaults['monitoring_expected_containers']).to match_array(
        %w[kw-app-postgres kw-app-redis kw-app-web kw-app-job kw-app-cron kamal-proxy]
      )
    end

    it 'uses the host-health check slug and conservative limits' do
      expect(defaults['monitoring_hc_slug']).to eq('kw-prod-host-health')
      expect(defaults['monitoring_disk_max_pct']).to eq(80)
      expect(defaults['monitoring_swap_max_pct']).to eq(50)
    end

    it 'checks the certificate of the production host, alerting under 21 days' do
      expect(defaults['monitoring_tls_check_host']).to eq('panel.kw.krakow.pl')
      expect(defaults['monitoring_tls_min_days']).to eq(21)
      expect(defaults['monitoring_tls_addr']).to eq('127.0.0.1:443')
      expect(templates.fetch('env.j2')).to include('KW_TLS_CHECK_HOST=', 'KW_TLS_MIN_DAYS=', 'KW_TLS_ADDR=')
      expect(tasks).to include('monitoring_tls_check_host')
    end

    it 'runs every 10 minutes and shortly after boot, as a hardened oneshot' do
      expect(templates.fetch('kw-host-check.timer.j2')).to match(/^OnCalendar=\*:0\/10$/)
      expect(templates.fetch('kw-host-check.timer.j2')).to match(/^OnBootSec=/)
      service = templates.fetch('kw-host-check.service.j2')
      expect(service).to include('Type=oneshot', 'ExecStart=/usr/local/sbin/kw-host-check', 'NoNewPrivileges=true')
      expect(service).to match(/^TimeoutStartSec=\d+$/)
    end

    it 'writes the env file root-only without logging its content, and reads the ping key from bws' do
      block = tasks.split(/^- name:/).find { |task| task.include?("dest: /etc/kw-monitoring/env\n") }
      expect(block).to be_present
      expect(block).to match(/mode: "0600"/)
      expect(block).to match(/owner: root/)
      expect(block).to match(/no_log: true/)
      expect(tasks).to match(/bws secret get/)
      expect(tasks).to match(/ansible\.builtin\.assert/)
    end

    it 'uses the ping-only healthchecks key, never the API key' do
      expect(defaults['monitoring_bws_secret_ids']['ping_key']).to eq('d37a01b2-04bd-44d1-8f96-b5060154a055')
      expect(role.join('defaults/main.yml').read).not_to match(/api-key/i)
    end

    it 'contains no literal secret in defaults, templates or files' do
      all = ([defaults.to_yaml] + templates.values + Dir[role.join('files/*').to_s].map { |f| File.read(f) }).join("\n")

      expect(all).not_to match(/AKIA|api[-_]?key|[0-9a-f]{32}/i)
    end

    it 'is part of the production playbook after mail' do
      playbook = YAML.safe_load(Rails.root.join('ansible/playbooks/production.yml').read)
      roles = playbook.first.fetch('roles').map { |r| r.is_a?(Hash) ? r['role'] : r }

      expect(roles).to include('monitoring')
      expect(roles.index('monitoring')).to be > roles.index('mail')
    end
  end
end
