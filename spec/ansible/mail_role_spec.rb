# frozen_string_literal: true

require 'rails_helper'
require 'open3'
require 'tmpdir'
require 'fileutils'
require 'yaml'

# The mail role (ansible/roles/mail, P6.5 in docs/NEW_PRODUCTION_PLAN.md) gives the host a way to tell the owner
# that something failed: a msmtp relay through Mailgun SMTP, unattended-upgrades mail on error, and one
# OnFailure= mail for the units that have no healthchecks.io heartbeat. Exceptions only, never a digest.
RSpec.describe 'ansible mail role' do # rubocop:disable RSpec/DescribeClass
  let(:role) { Rails.root.join('ansible/roles/mail') }
  let(:script) { role.join('files/kw-failure-mail').to_s }
  let(:tmp) { Pathname.new(Dir.mktmpdir('kw-mail-spec')) }
  let(:stubs) { tmp.join('bin') }
  let(:sent) { tmp.join('sent.eml') }
  let(:conf) { tmp.join('env') }

  after { FileUtils.remove_entry(tmp) }

  before do
    FileUtils.mkdir_p(stubs)
    write_stub('journalctl', <<~'SH')
      echo "journalctl $*" >> "$STUB_LOG"
      printf '2026-11-19T03:30:01+01:00 vps apt[1]: line one\n2026-11-19T03:30:02+01:00 vps apt[1]: line two\n'
    SH
    write_stub('sendmail', <<~'SH')
      echo "sendmail $*" >> "$STUB_LOG"
      cat > "$STUB_SENT"
      exit "${STUB_SENDMAIL_RC:-0}"
    SH
    write_stub('hostname', "echo vps-fb065f1c\n")
    File.write(conf, <<~ENV)
      KW_MAIL_TO='darek.finster@kw.krakow.pl'
      KW_MAIL_FROM='kw-prod-alerts@mg.example.test'
      KW_MAIL_TAG='kw-prod'
    ENV
  end

  def write_stub(name, body)
    path = stubs.join(name)
    File.write(path, "#!/usr/bin/env bash\n#{body}")
    FileUtils.chmod(0o755, path)
  end

  def run_script(*args, env: {})
    full_env = {
      'PATH' => "#{stubs}:#{ENV.fetch('PATH')}",
      'KW_MAIL_ENV' => conf.to_s,
      'KW_SENDMAIL' => stubs.join('sendmail').to_s,
      'STUB_LOG' => tmp.join('calls.log').to_s,
      'STUB_SENT' => sent.to_s
    }.merge(env)
    Open3.capture2e(full_env, script, *args)
  end

  def calls
    log = tmp.join('calls.log')
    log.exist? ? log.read.lines.map(&:chomp) : []
  end

  describe 'kw-failure-mail' do
    it 'mails the owner the unit name, host and the last journal lines' do
      out, status = run_script('apt-daily-upgrade.service')
      expect(status).to be_success, out

      mail = sent.read
      expect(mail).to include('To: darek.finster@kw.krakow.pl')
      expect(mail).to include('From: kw-prod-alerts@mg.example.test')
      expect(mail).to include('Subject: [kw-prod] apt-daily-upgrade.service failed on vps-fb065f1c')
      expect(mail).to include('line one', 'line two')
      expect(calls).to include('journalctl -u apt-daily-upgrade.service -n 40 --no-pager -o short-iso')
      expect(calls).to include('sendmail -t -i')
    end

    it 'sends exactly one message' do
      run_script('kw-reboot-if-needed.service')

      expect(calls.grep(/^sendmail /).size).to eq(1)
    end

    it 'fails (so the failure shows in systemd) when the mail cannot be sent' do
      _out, status = run_script('apt-daily-upgrade.service', env: { 'STUB_SENDMAIL_RC' => '75' })

      expect(status).not_to be_success
    end

    it 'still mails when the journal cannot be read' do
      write_stub('journalctl', "exit 1\n")

      out, status = run_script('apt-daily-upgrade.service')

      expect(status).to be_success, out
      expect(sent.read).to include('Subject: [kw-prod] apt-daily-upgrade.service failed')
    end

    it 'refuses a missing unit name and mails nothing' do
      _out, status = run_script

      expect(status).not_to be_success
      expect(calls.grep(/^sendmail /)).to be_empty
    end

    it 'refuses a unit name that could inject mail headers' do
      _out, status = run_script("evil.service\nBcc: someone@example.test")

      expect(status).not_to be_success
      expect(calls.grep(/^sendmail /)).to be_empty
    end

    it 'fails when its config file is missing' do
      FileUtils.rm(conf)

      _out, status = run_script('apt-daily-upgrade.service')

      expect(status).not_to be_success
      expect(calls.grep(/^sendmail /)).to be_empty
    end
  end

  describe 'role definition' do
    let(:tasks) { role.join('tasks/main.yml').read }
    let(:defaults) { YAML.safe_load(role.join('defaults/main.yml').read) }
    let(:templates) { Dir[role.join('templates/*').to_s].to_h { |path| [File.basename(path), File.read(path)] } }
    let(:msmtprc) { templates.fetch('msmtprc.j2') }

    it 'is valid YAML' do
      expect { YAML.safe_load(tasks) }.not_to raise_error
      expect(defaults).to be_a(Hash)
    end

    it 'mails the owner only, and only on error' do
      expect(defaults['mail_to']).to eq('darek.finster@kw.krakow.pl')
      expect(templates.fetch('53-kw-mail.conf.j2')).to include('Unattended-Upgrade::Mail "{{ mail_to }}"')
      expect(templates.fetch('53-kw-mail.conf.j2')).to include('Unattended-Upgrade::MailReport "only-on-error"')
    end

    it 'installs msmtp-mta so that /usr/sbin/sendmail exists' do
      expect(tasks).to match(/msmtp-mta/)
    end

    it 'talks to Mailgun over STARTTLS with certificate checking, and logs to syslog' do
      expect(msmtprc).to match(/^tls on$/)
      expect(msmtprc).to match(/^tls_starttls on$/)
      expect(msmtprc).to match(%r{^tls_trust_file /etc/ssl/certs/ca-certificates\.crt$})
      expect(msmtprc).to match(/^syslog on$/)
      expect(msmtprc).to match(/^host {{ mail_smtp_host }}$/)
    end

    it 'keeps the SMTP password out of msmtprc (passwordeval on a root-only file)' do
      expect(msmtprc).to match(%r{^passwordeval cat /etc/kw-mail/smtp-password$})
      expect(msmtprc).not_to match(/^password /)
    end

    it 'contains no literal secret in defaults, templates or files' do
      all = ([defaults.to_yaml] + templates.values + Dir[role.join('files/*').to_s].map { |f| File.read(f) }).join("\n")

      expect(all).not_to match(/AKIA|api[-_]?key|[0-9a-f]{32}/i)
    end

    it 'writes the SMTP files root-only and keeps their content out of logs' do
      %w[/etc/msmtprc /etc/kw-mail/smtp-password].each do |path|
        block = tasks.split(/^- name:/).find { |task| task.include?("dest: #{path}\n") }
        expect(block).to be_present, "no task writes #{path}"
        expect(block).to match(/mode: "0600"/)
        expect(block).to match(/owner: root/)
        expect(block).to match(/no_log: true/)
      end
    end

    it 'resolves the SMTP credentials from bws without logging them, and refuses to run without them' do
      expect(tasks).to match(/bws secret get/)
      expect(tasks).to match(/no_log: true/)
      expect(tasks).to match(/ansible\.builtin\.assert/)
      expect(tasks).to match(/mail_smtp_host/)
      expect(tasks).to match(/mail_from/)
    end

    it 'hooks the failure mail onto the units that have no healthchecks heartbeat' do
      expect(defaults['mail_failure_units']).to include('apt-daily-upgrade.service', 'kw-reboot-if-needed.service')
      expect(templates.fetch('kw-failure-mail@.service.j2')).to include('ExecStart=/usr/local/sbin/kw-failure-mail %i')
      expect(templates.fetch('onfailure.conf.j2')).to include('OnFailure=kw-failure-mail@%n.service')
    end

    it 'does not hook the backup jobs (they alert through healthchecks.io /fail)' do
      expect(defaults['mail_failure_units'].grep(/kw-backup|kw-restore|kw-restic/)).to be_empty
    end

    it 'is part of the production playbook' do
      playbook = YAML.safe_load(Rails.root.join('ansible/playbooks/production.yml').read)
      roles = playbook.first.fetch('roles').map { |r| r.is_a?(Hash) ? r['role'] : r }

      expect(roles).to include('mail')
    end
  end
end
