# frozen_string_literal: true

require 'rails_helper'
require 'open3'
require 'tmpdir'
require 'fileutils'
require 'yaml'

# The backup role (ansible/roles/backup) is the only thing between the production database and data loss,
# so its scripts are exercised for real here, with docker/restic/curl/python3 replaced by stubs on PATH.
RSpec.describe 'ansible backup role' do # rubocop:disable RSpec/DescribeClass
  let(:role) { Rails.root.join('ansible/roles/backup') }
  let(:lib) { role.join('files/kw-backup-lib.sh').to_s }
  let(:tmp) { Pathname.new(Dir.mktmpdir('kw-backup-spec')) }
  let(:backup_dir) { tmp.join('dumps') }
  let(:stubs) { tmp.join('bin') }
  let(:log) { tmp.join('calls.log') }
  let(:env_file) { tmp.join('env') }

  after { FileUtils.remove_entry(tmp) }

  before do
    FileUtils.mkdir_p([stubs, tmp.join('lock')])
    write_stub('docker', <<~'SH')
      echo "docker $*" >> "$STUB_LOG"
      case "$*" in
        *pg_dump*)
          case "${STUB_DUMP_MODE:-ok}" in
            fail) echo "pg_dump: error" >&2; exit 1 ;;
            truncated) printf -- '-- PostgreSQL database dump\nCOPY x\n' ;;
            *) printf -- '-- PostgreSQL database dump\nSELECT 1;\n-- PostgreSQL database dump complete\n' ;;
          esac ;;
        *--single-transaction*)
          cat > /dev/null
          [ "${STUB_LOAD_FAIL:-0}" = 1 ] && exit 1 ;;
        *psql*)
          sed 's/^/  stdin: /' >> "$STUB_LOG" ;;
      esac
      exit 0
    SH
    write_stub('restic', <<~'SH')
      echo "restic $*" >> "$STUB_LOG"
      [ "$1" = cat ] && [ "${STUB_NO_REPO:-0}" = 1 ] && exit 1
      [ "$1" = "${STUB_RESTIC_FAIL:-}" ] && exit 1
      exit 0
    SH
    write_stub('curl', <<~'SH')
      echo "curl $*" >> "$STUB_LOG"
      exit "${STUB_CURL_RC:-0}"
    SH
    write_stub('python3', <<~'SH')
      echo "python3 $*" >> "$STUB_LOG"
      exit "${STUB_DIGEST_RC:-0}"
    SH
    File.write(env_file, <<~ENV)
      AWS_ACCESS_KEY_ID='AKIAFAKEFAKEFAKE'
      RESTIC_REPOSITORY='s3:https://s3.example.test/bucket'
      RESTIC_PASSWORD='fake-restic-password'
      RESTIC_CACHE_DIR='#{tmp.join('cache')}'
      RESTIC_CHECK_SUBSET='5%'
      HC_PING_KEY='PINGKEY123'
      BACKUP_DIR='#{backup_dir}'
      PG_CONTAINER='kw-app-postgres'
      PG_USER='production_user'
      PG_DB='kw_app_production'
      RESTORE_DB='kw_restore_test'
      KEEP_DAILY='7'
      KEEP_WEEKLY='4'
      KEEP_MONTHLY='6'
    ENV
  end

  def write_stub(name, body)
    path = stubs.join(name)
    File.write(path, "#!/usr/bin/env bash\n#{body}")
    FileUtils.chmod(0o755, path)
  end

  def run_job(job, extra_env = {})
    env = {
      'PATH' => "#{stubs}:#{ENV.fetch('PATH')}",
      'KW_BACKUP_LIB' => lib,
      'KW_BACKUP_ENV' => env_file.to_s,
      'KW_LOCK_DIR' => tmp.join('lock').to_s,
      'KW_TABLE_DIGEST' => '/stub/table_digest.py',
      'HC_PING_BASE' => 'https://hc.test',
      'STUB_LOG' => log.to_s
    }.merge(extra_env)
    Open3.capture2e(env, role.join("files/#{job}").to_s)
  end

  def calls
    log.exist? ? log.read.lines.map(&:chomp) : []
  end

  def pings
    calls.grep(/^curl /).map { |l| l[%r{https://hc\.test/\S+}] }
  end

  def dumps
    Dir[backup_dir.join('*.sql.gz').to_s]
  end

  describe 'kw-backup' do
    it 'dumps, records a checksum, copies off-site and pings success once' do
      out, status = run_job('kw-backup')
      expect(status).to be_success, out

      expect(dumps.size).to eq(1)
      expect(File.exist?("#{dumps.first}.sha256")).to be(true)
      expect(File.stat(dumps.first).mode & 0o777).to eq(0o600)
      expect(Dir[backup_dir.join('*.partial').to_s]).to be_empty
      expect(calls).to include('docker exec kw-app-postgres pg_dump -U production_user kw_app_production')
      expect(calls.grep(/^restic backup --host kw-prod --tag nightly #{Regexp.escape(dumps.first)}/).size).to eq(1)
      expect(calls).to include('restic forget --host kw-prod --tag nightly --group-by host,tags ' \
                               '--keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune')
      expect(pings).to eq(['https://hc.test/PINGKEY123/kw-prod-backup-nightly'])
    end

    it 'initialises the restic repository only when it does not exist yet' do
      run_job('kw-backup')
      expect(calls).not_to include('restic init')

      run_job('kw-backup', 'STUB_NO_REPO' => '1')
      expect(calls).to include('restic init')
    end

    it 'pings /fail and leaves no dump behind when pg_dump fails' do
      out, status = run_job('kw-backup', 'STUB_DUMP_MODE' => 'fail')
      expect(status).not_to be_success
      expect(out).to include('FAILED')
      expect(pings).to eq(['https://hc.test/PINGKEY123/kw-prod-backup-nightly/fail'])
      expect(dumps).to be_empty
      expect(Dir[backup_dir.join('*').to_s]).to be_empty
      expect(calls.grep(/^restic backup/)).to be_empty
    end

    it 'rejects a dump without the completion marker' do
      _out, status = run_job('kw-backup', 'STUB_DUMP_MODE' => 'truncated')
      expect(status).not_to be_success
      expect(pings.last).to end_with('/kw-prod-backup-nightly/fail')
      expect(dumps).to be_empty
      expect(calls.grep(/^restic backup/)).to be_empty
    end

    it 'keeps the local dump but pings /fail when the off-site copy fails' do
      _out, status = run_job('kw-backup', 'STUB_RESTIC_FAIL' => 'backup')
      expect(status).not_to be_success
      expect(pings).to eq(['https://hc.test/PINGKEY123/kw-prod-backup-nightly/fail'])
      expect(dumps.size).to eq(1)
      expect(calls.grep(/^restic forget/)).to be_empty
    end

    it 'does not turn an undeliverable ping into a job failure' do
      out, status = run_job('kw-backup', 'STUB_CURL_RC' => '7')
      expect(status).to be_success, out
      expect(out).to include('ping failed')
    end

    it 'never prints secrets' do
      out, = run_job('kw-backup')
      expect(out).not_to include('fake-restic-password')
      expect(out).not_to include('AKIAFAKEFAKEFAKE')
    end

    it 'fails (and pings nothing) when the env file is missing' do
      _out, status = run_job('kw-backup', 'KW_BACKUP_ENV' => tmp.join('nope').to_s)
      expect(status.exitstatus).to eq(2)
      expect(pings).to be_empty
    end
  end

  describe 'kw_prune_local' do
    def prune(dir)
      out, status = Open3.capture2e('bash', '-c', ". #{lib} && kw_prune_local #{dir} 7 4 6")
      expect(status).to be_success, out
    end

    def stamp(date)
      "kw_app_production-#{date.strftime('%Y%m%d')}T021500Z.sql.gz"
    end

    it 'keeps 7 daily, 4 weekly and 6 monthly dumps and removes the rest with their checksums' do
      FileUtils.mkdir_p(backup_dir)
      (Date.new(2026, 1, 1)..Date.new(2026, 3, 31)).each do |d|
        FileUtils.touch([backup_dir.join(stamp(d)), backup_dir.join("#{stamp(d)}.sha256")])
      end
      FileUtils.touch(backup_dir.join('notes.txt'))

      prune(backup_dir)

      kept = dumps.map { |f| File.basename(f)[/-(\d{8})T/, 1] }.sort
      # 7 newest days, the newest of the 2 older ISO weeks (W12, W11), the newest of Feb and Jan
      expected = %w[20260331 20260330 20260329 20260328 20260327 20260326 20260325
                    20260322 20260315 20260228 20260131].sort
      expect(kept).to eq(expected)
      expect(Dir[backup_dir.join('*.sha256').to_s].size).to eq(expected.size)
      expect(File.exist?(backup_dir.join('notes.txt'))).to be(true)
    end

    it 'keeps only the newest dump of a day' do
      FileUtils.mkdir_p(backup_dir)
      %w[020000 130000].each { |t| FileUtils.touch(backup_dir.join("kw_app_production-20260331T#{t}Z.sql.gz")) }
      Open3.capture2e('bash', '-c', ". #{lib} && kw_prune_local #{backup_dir} 1 0 0")
      expect(dumps.map { |f| File.basename(f) }).to eq(['kw_app_production-20260331T130000Z.sql.gz'])
    end

    it 'does nothing in an empty directory' do
      FileUtils.mkdir_p(backup_dir)
      prune(backup_dir)
      expect(dumps).to be_empty
    end
  end

  describe 'kw-restore-test' do
    before do
      FileUtils.mkdir_p(backup_dir)
      @dump = backup_dir.join('kw_app_production-20260331T021500Z.sql.gz')
      Zlib::GzipWriter.open(@dump) { |gz| gz.write("-- PostgreSQL database dump complete\n") }
      Dir.chdir(backup_dir) { File.write("#{@dump.basename}.sha256", `sha256sum #{@dump.basename}`) }
    end

    it 'restores the newest dump into the scratch DB, verifies it, drops it and pings success' do
      out, status = run_job('kw-restore-test')
      expect(status).to be_success, out

      expect(calls.join("\n")).to include('CREATE DATABASE kw_restore_test;')
      expect(calls.grep(/--single-transaction/).size).to eq(1)
      expect(calls).to include("python3 /stub/table_digest.py verify #{@dump} --psql docker exec -i kw-app-postgres " \
                               'psql -U production_user -d kw_restore_test -X -q -At')

      expect(calls.grep(/stdin: DROP DATABASE IF EXISTS kw_restore_test;/).size).to eq(2)
      expect(pings).to eq(['https://hc.test/PINGKEY123/kw-prod-restore-test'])
    end

    it 'uses the newest of several dumps' do
      newer = backup_dir.join('kw_app_production-20260401T021500Z.sql.gz')
      FileUtils.cp(@dump, newer)
      Dir.chdir(backup_dir) { File.write("#{newer.basename}.sha256", `sha256sum #{newer.basename}`) }
      run_job('kw-restore-test')
      expect(calls.grep(/^python3/).first).to include(newer.to_s)
    end

    it 'pings /fail and still drops the scratch DB when the digest check fails' do
      _out, status = run_job('kw-restore-test', 'STUB_DIGEST_RC' => '1')
      expect(status).not_to be_success
      expect(pings).to eq(['https://hc.test/PINGKEY123/kw-prod-restore-test/fail'])
      expect(calls.grep(/stdin: DROP DATABASE IF EXISTS kw_restore_test;/).size).to eq(2)
    end

    it 'pings /fail and still drops the scratch DB when loading the dump fails' do
      _out, status = run_job('kw-restore-test', 'STUB_LOAD_FAIL' => '1')
      expect(status).not_to be_success
      expect(pings.last).to end_with('/kw-prod-restore-test/fail')
      expect(calls.grep(/^python3/)).to be_empty
      expect(calls.grep(/stdin: DROP DATABASE IF EXISTS kw_restore_test;/).size).to eq(2)
    end

    it 'pings /fail when the dump does not match its checksum' do
      File.open(@dump, 'ab') { |f| f.write('corrupt') }
      _out, status = run_job('kw-restore-test')
      expect(status).not_to be_success
      expect(pings.last).to end_with('/kw-prod-restore-test/fail')
      expect(calls.grep(/--single-transaction/)).to be_empty
    end

    it 'pings /fail when there is no dump at all' do
      FileUtils.rm_f(Dir[backup_dir.join('*').to_s])
      _out, status = run_job('kw-restore-test')
      expect(status).not_to be_success
      expect(pings.last).to end_with('/kw-prod-restore-test/fail')
    end

    it 'refuses to use the live database as the scratch database' do
      File.write(env_file, "#{env_file.read}RESTORE_DB='kw_app_production'\n")
      _out, status = run_job('kw-restore-test')
      expect(status).not_to be_success
      expect(calls.grep(/DROP DATABASE/)).to be_empty
      expect(calls.grep(/CREATE DATABASE/)).to be_empty
    end
  end

  describe 'kw-restic-check' do
    it 'checks a data subset and pings success' do
      out, status = run_job('kw-restic-check')
      expect(status).to be_success, out
      expect(calls).to include('restic check --read-data-subset=5%')
      expect(pings).to eq(['https://hc.test/PINGKEY123/kw-prod-restic-check'])
    end

    it 'pings /fail when restic check fails' do
      _out, status = run_job('kw-restic-check', 'STUB_RESTIC_FAIL' => 'check')
      expect(status).not_to be_success
      expect(pings).to eq(['https://hc.test/PINGKEY123/kw-prod-restic-check/fail'])
    end
  end

  describe 'role definition' do
    let(:tasks) { YAML.load_file(role.join('tasks/main.yml')) }
    let(:defaults) { YAML.load_file(role.join('defaults/main.yml')) }
    let(:job_names) { defaults.fetch('backup_jobs').map { |j| j.fetch('name') } }

    it 'ships a script for every job, all executable' do
      expect(job_names).to contain_exactly('kw-backup', 'kw-restore-test', 'kw-restic-check')
      job_names.each { |n| expect(File.executable?(role.join("files/#{n}"))).to be(true), n }
    end

    it 'contains no literal secret in the templates or files (only variables)' do
      Dir[role.join('{templates,files}/*').to_s].each do |path|
        expect(File.read(path)).not_to match(/\b[0-9a-fA-F]{32,}\b/), path
      end
      env_template = File.read(role.join('templates/kw-backup.env.j2'))
      %w[AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY RESTIC_PASSWORD HC_PING_KEY].each do |key|
        expect(env_template).to match(/^#{key}='\{\{ backup_secrets\.\w+ \}\}'$/)
      end
    end

    it 'writes the env file root-only and keeps its content out of logs' do
      task = tasks.find { |t| t['name'] == 'Write the backup environment file' }
      expect(task).to include('no_log' => true)
      args = task.fetch('ansible.builtin.template')
      expect(args).to include('dest' => '/etc/kw-backup/env', 'owner' => 'root', 'group' => 'root', 'mode' => '0600')
    end

    it 'resolves secrets from bws without logging them' do
      task = tasks.find { |t| t['name'] == 'Read the backup secrets from Bitwarden Secrets Manager' }
      expect(task).to include('no_log' => true)
      expect(defaults.fetch('backup_bws_secret_ids').keys).to contain_exactly(
        'access_key', 'secret_key', 'restic_password', 'ping_key'
      )
    end

    it 'schedules every job in Europe/Warsaw and catches up after downtime' do
      defaults.fetch('backup_jobs').each do |job|
        expect(job.fetch('calendar')).to match(/backup_\w+_calendar/)
      end
      %w[backup_nightly_calendar backup_restore_test_calendar backup_check_calendar].each do |key|
        expect(defaults.fetch(key)).to end_with('Europe/Warsaw')
      end
      timer = File.read(role.join('templates/kw-job.timer.j2'))
      expect(timer).to include('Persistent=true')
    end

    it 'pins restic to a version and a checksum' do
      expect(defaults.fetch('backup_restic_version')).to match(/\A\d+\.\d+\.\d+\z/)
      expect(defaults.fetch('backup_restic_sha256')).to match(/\A\h{64}\z/)
    end

    it 'is part of the production playbook' do
      play = YAML.load_file(Rails.root.join('ansible/playbooks/production.yml')).first
      expect(play.fetch('roles')).to include(a_hash_including('role' => 'backup', 'tags' => ['backup']))
    end
  end
end
