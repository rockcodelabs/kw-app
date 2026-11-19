# frozen_string_literal: true

# Staging controller check harness.
#
# Piped (together with a scenario file) into `bin/rails runner -` inside the
# running staging web container. See SKILL.md for the exact command.
#
# Safety model:
#   * refuses to run unless Rails.env == staging, with ONE exception: Rails.env == production is
#     accepted only when HARNESS_ALLOW_PRODUCTION=yes is passed explicitly (P7 rehearsal dry run and the
#     post-flip check after P8, see bin/post-deploy-check). Production runs are safe because of the
#     measures below; on a live database the row-count comparison is replaced by a leftover check.
#   * every write happens inside ONE transaction that is always rolled back
#   * ActiveJob -> :test adapter, ActionMailer -> :test (no Mailgun, no Sidekiq)
#   * refuses to run while AppSignal is active (run with -e APPSIGNAL_ACTIVE=false)
#   * users are throwaway records (*@example.invalid), logged in via Warden
#     test mode, so no real credentials are involved
#   * after rollback the harness verifies that no throwaway row is left (users *@example.invalid and
#     records named `stg-check*`); outside production it also verifies that no row counts changed.
#     Scenarios MUST name every record they create `stg-check ...` so this check can see it.

unless Rails.env.staging? || (Rails.env.production? && ENV['HARNESS_ALLOW_PRODUCTION'] == 'yes')
  abort 'Refusing to run: Rails.env is not staging (production needs HARNESS_ALLOW_PRODUCTION=yes)'
end

require 'securerandom'

module StagingHarness
  EMAIL_DOMAIN = 'example.invalid'
  TRACKED_MODELS = %w[
    Db::User
    Db::Profile
    Db::Payment
    Db::Reservation
    Db::Item
    Training::Supplementary::CourseRecord
    Training::Supplementary::SignUpRecord
    Training::Supplementary::PackageTypeRecord
    Settlement::ContractRecord
    Settlement::ContractorRecord
    NotificationCenter::NotificationRecord
    Db::Activities::MountainRoute
    Db::Activities::RouteColleagues
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
      @session.host! ENV.fetch('HARNESS_HOST', Rails.env.production? ? 'panel.kw.krakow.pl' : 'staging-check.local')
      @session.https! if Rails.env.production?
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
      @gaps = 0
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

      verify_rollback(before)
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

    # A documented, accepted-for-now finding (e.g. "G24"). `expected` describes the INTENDED behaviour.
    # While the gap exists it prints GAP and does not fail the run; once the behaviour is fixed it is
    # counted as a normal passing check, so the entry can be promoted to a plain `check`.
    def known_gap(id, name, actual, expected)
      ok = expected === actual # rubocop:disable Style/CaseEquality
      if ok
        @checks << { name: "[#{id} fixed] #{name}", ok: true, detail: nil }
        puts format('  PASS [%s fixed] %s  -> promote this to a plain check', id, name)
      else
        @gaps = (@gaps || 0) + 1
        puts format('  GAP  [%s] %s  -> expected %s, got %s', id, name, expected.inspect, actual.inspect)
      end
      ok
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
      # Same behaviour on every host: an exception becomes a 500 response and is exposed via
      # Response#exception instead of propagating into the scenario (the test env disables this).
      Rails.application.env_config['action_dispatch.show_exceptions'] = true
      Rails.application.env_config['action_dispatch.show_detailed_exceptions'] = false
      Warden.test_mode!
      Membership::Activement.prepend(ActiveOverride) unless Membership::Activement.ancestors.include?(ActiveOverride)

      mail_adapter = ActionMailer::MailDeliveryJob.queue_adapter
      return if mail_adapter.is_a?(ActiveJob::QueueAdapters::TestAdapter)

      abort "Refusing to run: mail jobs would use #{mail_adapter.class}, not the test adapter"
    end

    def snapshot
      TRACKED_MODELS.to_h { |name| [name, name.constantize.unscoped.count] }
    end

    # Rows that only the harness creates. Must be empty after the rollback, on every host.
    def leftovers
      {
        'users' => Db::User.where('email LIKE ?', "%@#{EMAIL_DOMAIN}").count,
        'courses' => Training::Supplementary::CourseRecord.where("name LIKE 'stg-check%'").count,
        'sign-ups' => Training::Supplementary::SignUpRecord.where("email LIKE '%@#{EMAIL_DOMAIN}'").count,
        'contracts' => Settlement::ContractRecord.where("title LIKE 'stg-check%'").count,
        'items' => Db::Item.where("display_name LIKE 'stg-check%'").count
      }
    end

    def verify_rollback(before)
      check('rollback left no throwaway rows behind', leftovers.select { |_, n| n.positive? }, {})
      if Rails.env.production?
        info('row counts', 'not compared on production (live traffic may change them)')
      else
        check('rollback left no data behind', snapshot, before)
      end
    end

    def summarize
      failed = @checks.reject { |c| c[:ok] }
      puts
      puts "== #{@checks.size - failed.size}/#{@checks.size} checks passed#{@gaps.to_i.positive? ? ", #{@gaps} known gap(s) open (GAP lines, not failures)" : ''}"
      failed.each { |c| puts "   FAIL #{c[:name]}  -> #{c[:detail]}" } if failed.any?
      exit(failed.empty? ? 0 : 1)
    end
  end
end
