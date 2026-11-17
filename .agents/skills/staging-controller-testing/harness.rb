# frozen_string_literal: true

# Staging controller check harness.
#
# Piped (together with a scenario file) into `bin/rails runner -` inside the
# running staging web container. See SKILL.md for the exact command.
#
# Safety model:
#   * refuses to run unless Rails.env == staging
#   * every write happens inside ONE transaction that is always rolled back
#   * ActiveJob -> :test adapter, ActionMailer -> :test (no Mailgun, no Sidekiq)
#   * refuses to run while AppSignal is active (run with -e APPSIGNAL_ACTIVE=false)
#   * users are throwaway records (*@example.invalid), logged in via Warden
#     test mode, so no real credentials are involved
#   * after rollback the harness verifies that no row counts changed

abort 'Refusing to run: Rails.env is not staging' unless Rails.env.staging?

require 'securerandom'

module StagingHarness
  EMAIL_DOMAIN = 'example.invalid'
  TRACKED_MODELS = %w[
    Db::User
    Db::Profile
    Db::Payment
    Settlement::ContractRecord
    Settlement::ContractorRecord
    NotificationCenter::NotificationRecord
    PaperTrail::Version
  ].freeze

  FORCED_ACTIVE_IDS = Set.new

  # Making a user a real "active member" requires membership fee + payment
  # records. For controller checks we only need Ability#active to be true.
  module ActiveOverride
    def active?
      FORCED_ACTIVE_IDS.include?(user&.id) || super
    end
  end

  Response = Struct.new(:status, :location, :body, :content_type, :exception, :headers, keyword_init: true) do
    def redirect?
      (300..399).cover?(status)
    end

    def error_summary
      exception && "#{exception.class}: #{exception.message.to_s[0, 120]}"
    end
  end

  # Thin wrapper around an integration session bound to one (optional) user.
  class Client
    attr_reader :user, :label

    def initialize(label, user)
      @label = label
      @user = user
      @session = ActionDispatch::Integration::Session.new(Rails.application)
      @session.host! 'staging-check.local'
    end

    %i[get post put patch delete].each do |verb|
      define_method(verb) do |path, params: {}|
        perform(verb, path, params)
      end
    end

    private

    def perform(verb, path, params)
      StagingHarness.login_as(user, scope: :user) if user
      @session.public_send(verb, path, params: params)
      response = @session.response
      Response.new(
        status: response.status,
        location: response.location,
        body: response.body.to_s,
        content_type: response.media_type,
        exception: @session.request.env['action_dispatch.exception'],
        headers: response.headers.to_h
      )
    end
  end

  class << self
    include Warden::Test::Helpers

    attr_reader :checks

    def routes
      Rails.application.routes.url_helpers
    end

    # Entry point used by scenarios.
    def run(title)
      isolate_side_effects!
      @checks = []
      @kw_id_seq = Db::User.maximum(:kw_id).to_i + 1000
      before = snapshot

      puts "== #{title} (#{Rails.env}, db=#{ActiveRecord::Base.connection.current_database})"
      begin
        ActiveRecord::Base.transaction do
          yield self
          raise ActiveRecord::Rollback
        end
      rescue StandardError => e
        check('scenario ran without raising', false, true, extra: "#{e.class}: #{e.message[0, 200]}")
        puts e.backtrace.first(8).map { |l| "     #{l}" }
      end

      after = snapshot
      check('rollback left no data behind', after, before)
      summarize
    end

    # --- fixtures ---------------------------------------------------------

    def user(label, roles: [], active: false)
      @kw_id_seq += 1
      created = Db::User.create!(
        email: "stg-check+#{label}-#{SecureRandom.hex(3)}@#{EMAIL_DOMAIN}",
        password: SecureRandom.hex(5),
        first_name: 'Stg',
        last_name: label.to_s.capitalize,
        phone: '000000000',
        kw_id: @kw_id_seq,
        roles: roles.map(&:to_s)
      )
      FORCED_ACTIVE_IDS << created.id if active
      created
    end

    def client(label = 'anonymous', user = nil)
      Client.new(label, user)
    end

    # --- assertions -------------------------------------------------------

    # `expected` is compared with ===, so it may be a value, Range or Regexp.
    # With any: true an Array means "any of these" (used for HTTP statuses).
    def check(name, actual, expected, extra: nil, any: false)
      expectations = any ? Array(expected) : [expected]
      ok = expectations.any? { |e| e === actual } # rubocop:disable Style/CaseEquality
      detail = ok ? nil : "expected #{expected.inspect}, got #{actual.inspect}"
      detail = [detail, extra].compact.join(' | ') if extra
      @checks << { name: name, ok: ok, detail: detail }
      puts format('  %-4s %s%s', ok ? 'PASS' : 'FAIL', name, detail ? "  -> #{detail}" : '')
      ok
    end

    def check_status(name, response, expected)
      check(name, response.status, expected, extra: response.error_summary, any: true)
    end

    # CanCan::AccessDenied is rescued in ApplicationController with
    # redirect_back(fallback_location: root), so "denied" == 401/403 or a
    # redirect to the root page. A bare 302 is NOT enough: success also redirects.
    def check_denied(name, response)
      location_path = response.location && URI.parse(response.location).path
      ok = [401, 403].include?(response.status) || (response.redirect? && location_path == '/')
      detail = ok ? nil : "status #{response.status}, location #{response.location.inspect}"
      detail = [detail, response.error_summary].compact.join(' | ') unless ok
      @checks << { name: name, ok: ok, detail: detail }
      puts format('  %-4s %s%s', ok ? 'PASS' : 'FAIL', name, detail ? "  -> expected denial, got #{detail}" : '')
      ok
    end

    # Informational line that is not a pass/fail check (e.g. "not testable here").
    def info(name, text)
      puts format('  INFO %s  -> %s', name, text)
    end

    # --- job / mail helpers ----------------------------------------------

    # Runs the block with mail jobs executed inline and returns the messages
    # that ActionMailer's :test delivery method collected. Nothing leaves the
    # process (delivery_method is forced to :test by isolate_side_effects!).
    # Non-mail jobs enqueued inside the block are dropped, not run.
    def capture_mail
      abort 'Refusing to capture mail: delivery_method is not :test' unless ActionMailer::Base.delivery_method == :test

      adapter = ActiveJob::Base.queue_adapter
      adapter.perform_enqueued_jobs = true
      adapter.filter = [ActionMailer::Base.delivery_job]
      ActionMailer::Base.perform_deliveries = true
      ActionMailer::Base.deliveries.clear
      yield
      ActionMailer::Base.deliveries.dup
    ensure
      adapter.perform_enqueued_jobs = false
      adapter.filter = nil
      ActionMailer::Base.perform_deliveries = false
      ActionMailer::Base.deliveries.clear
    end

    def enqueued_jobs
      ActiveJob::Base.queue_adapter.enqueued_jobs
    end

    def clear_enqueued_jobs!
      enqueued_jobs.clear
    end

    private

    def isolate_side_effects!
      if defined?(Appsignal) && Appsignal.active?
        abort 'Refusing to run: AppSignal is active and would report test traffic/errors to the staging ' \
              'app. Add `-e APPSIGNAL_ACTIVE=false` to `docker exec`.'
      end

      ActiveJob::Base.queue_adapter = :test
      ActionMailer::Base.delivery_method = :test
      ActionMailer::Base.perform_deliveries = false
      ActionController::Base.allow_forgery_protection = false
      Warden.test_mode!
      Membership::Activement.prepend(ActiveOverride) unless Membership::Activement.ancestors.include?(ActiveOverride)

      mail_adapter = ActionMailer::MailDeliveryJob.queue_adapter
      return if mail_adapter.is_a?(ActiveJob::QueueAdapters::TestAdapter)

      abort "Refusing to run: mail jobs would use #{mail_adapter.class}, not the test adapter"
    end

    def snapshot
      TRACKED_MODELS.to_h { |name| [name, name.constantize.unscoped.count] }
    end

    def summarize
      failed = @checks.reject { |c| c[:ok] }
      puts
      puts "== #{@checks.size - failed.size}/#{@checks.size} checks passed"
      failed.each { |c| puts "   FAIL #{c[:name]}  -> #{c[:detail]}" } if failed.any?
      exit(failed.empty? ? 0 : 1)
    end
  end
end
