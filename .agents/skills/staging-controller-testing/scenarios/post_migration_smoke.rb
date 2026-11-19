# frozen_string_literal: true

# Scenario: post-migration smoke test (docs/NEW_PRODUCTION_PLAN.md, Appendix B).
# Run together with harness.rb (see SKILL.md). Everything is rolled back; mail goes to
# ActionMailer's :test delivery only; nothing is sent to Mailgun, Dotpay or Redis.
#
# Check IDs (B-xx) match the checklist in the plan. The only outbound traffic is
# read-only: an OpenStack token request and one HEAD request (B-FIL).
#
# Secrets are never printed: only present?/length.

StagingHarness.run('Post-migration smoke') do |h|
  r    = h.routes
  anon = h.client
  as   = ->(label, user) { h.client(label, user) }

  # Runs a block as one check; an exception becomes a FAIL instead of aborting the scenario.
  attempt = lambda do |name, expected = true, &block|
    actual = begin
      block.call
    rescue StandardError => e
      "#{e.class}: #{e.message[0, 100]}"
    end
    h.check(name, actual, expected)
  end

  # --- B-INF: health ------------------------------------------------------
  puts '-- B-INF health'
  h.check_status('GET /up is 200 (anonymous)', anon.get('/up'), 200)

  # --- B-LOG: login, logout, password reset ------------------------------
  puts '-- B-LOG login / logout / reset'
  member = h.user('login', active: true)
  member.update!(password: 'Smoke123456', password_confirmation: 'Smoke123456')
  h.check_status('login page /zaloguj renders', anon.get('/zaloguj'), 200)

  session = h.client('login-session')
  bad = session.post('/users/sign_in', params: { user: { email: member.email, password: 'wrong-password' } })
  h.check_status('wrong password is rejected (no redirect to root)', bad, [200, 401, 422])
  good = session.post('/users/sign_in', params: { user: { email: member.email, password: 'Smoke123456' } })
  h.check_status('correct password signs in (redirect)', good, [302, 303])
  h.check_status('signed-in session can read /notifications', session.get('/notifications'), 200)
  member.reload
  h.check('sign-in recorded (trackable)', member.sign_in_count.to_i, 1..)
  h.check_status('sign out redirects (devise sign_out_via is GET)', session.get('/users/sign_out'), [302, 303])
  h.check_status('after sign out /notifications is not 200', session.get('/notifications'), [302, 401])

  mails = h.capture_mail { anon.post('/users/password', params: { user: { email: member.email } }) }
  reset = mails.find { |m| Array(m.to).include?(member.email) }
  h.check('password reset e-mail rendered for the user', reset.present?, true)
  if reset
    body = reset.body.parts.any? ? reset.body.parts.map(&:to_s).join : reset.body.to_s
    h.check('reset e-mail contains a reset_password_token link', body, /reset_password_token=/)
    h.check('reset e-mail links to the configured host', body, %r{https?://[a-z0-9.-]+/})
    h.info('reset e-mail link host', body[%r{https?://[a-z0-9.:-]+}].to_s)
    h.info('reset e-mail from', Array(reset.from).map { |a| a.sub(/^.*@/, '***@') }.join(','))
  end

  # --- B-REG: registration ------------------------------------------------
  puts '-- B-REG registration'
  reg_client = h.client('registration')
  h.check_status('/zarejestruj renders', reg_client.get('/zarejestruj'), 200)
  reg_email = "stg-check+reg-#{SecureRandom.hex(3)}@#{StagingHarness::EMAIL_DOMAIN}"
  before = Db::User.count
  reg = reg_client.post('/users', params: { user: { email: reg_email, password: 'Smoke123456', password_confirmation: 'Smoke123456',
                                              first_name: 'Reg', last_name: 'Check', phone: '000000000', kw_id: 999_999_001 } })
  h.check_status('registration responds without 500', reg, [200, 302])
  h.info('registration created a user (open self-registration)', (Db::User.count - before).to_s)

  # --- B-PRO: profile creation -------------------------------------------
  puts '-- B-PRO profile creation'
  h.check_status('v2 application form renders', anon.get('/v2/profiles/new'), 200)
  h.check_status('legacy application form /zgloszenie renders', anon.get('/zgloszenie'), 200)
  h.check('reactivation form is routed to profiles#reactivation (not shadowed by visiting_card)',
          Rails.application.routes.recognize_path('/profiles/reactivation')[:action], 'reactivation')
  profile_email = "stg-check+profile-#{SecureRandom.hex(3)}@#{StagingHarness::EMAIL_DOMAIN}"
  valid_profile = {
    profile: {
      locale: 'pl', first_name: 'Stg', last_name: 'Profile', email: profile_email, gender: 'male',
      birth_place: 'Krakow', birth_date: '1990-01-01', city: 'Krakow', postal_code: '30-001', phone: '000000000',
      acomplished_courses: ['basic_kw'], optional_address: 'ul. Testowa 1', sections: ['snw'],
      course_cert: '', photo: '', main_discussion_group: 'true', terms_of_service: '1'
    }
  }
  invalid = anon.post('/v2/profiles', params: { profile: valid_profile[:profile].merge(email: 'not-an-email') })
  h.check_status('v2 invalid application re-renders the form', invalid, 200)
  count = Db::Profile.count
  created = anon.post('/v2/profiles', params: valid_profile)
  h.check_status('v2 valid application redirects', created, 302)
  h.check('v2 valid application persisted exactly one profile', Db::Profile.count - count, 1)

  # --- B-ADM: admin accepts the profile (user + reset mail + accepted mail with PDF) ---
  puts '-- B-ADM admin accepts profile'
  admin = h.user('admin', roles: %w[admin])
  profile = Db::Profile.find_by(email: profile_email)
  if profile
    profile.create_payment(dotpay_id: SecureRandom.hex(13)) unless profile.payment
    seq = Db::User.maximum(:kw_id).to_i + 500
    h.check_status('admin profile list renders', as.('admin', admin).get(r.admin_profiles_path), 200)
    xlsx = as.('admin', admin).get(r.admin_profiles_path(format: :xlsx))
    h.check_status('admin profile list exports xlsx', xlsx, 200)
    h.check('xlsx content type', xlsx.content_type.to_s, /spreadsheet/)
    accepted_mails = h.capture_mail do
      as.('admin', admin).put("/admin/profiles/#{profile.id}/accept",
                              params: { profile: { kw_id: seq, application_date: Date.current.to_s } })
    end
    h.check('accept created the member user', Db::User.exists?(email: profile_email), true)
    h.check('accept sent password-reset and accepted e-mails', accepted_mails.size, 2..)
    h.info('accept e-mail subjects', accepted_mails.map { |m| m.subject.to_s[0, 50] }.inspect)
  else
    h.check('v2 profile exists for the accept step', false, true)
  end

  attempt.call('ProfileMailer.apply renders with a PDF attachment (G20)', true) do
    pf = Db::Profile.find_by(email: profile_email)
    m = ProfileMailer.apply(pf).message
    m.attachments.any? { |a| a.filename.to_s.end_with?('.pdf') && a.body.raw_source.to_s.start_with?('%PDF') }
  end

  # --- B-MAIL: every mailer action has a template ------------------------
  puts '-- B-MAIL mailer templates'
  Rails.application.eager_load!
  missing = []
  ApplicationMailer.descendants.each do |klass|
    klass.action_methods.each do |action|
      found = klass.new.lookup_context.exists?(action.to_s, [klass.mailer_name], false)
      missing << "#{klass.name}##{action}" unless found
    end
  end
  h.check('every ApplicationMailer action has a template', missing, [])
  # Messaging mailer actions pick explicit template names (Mailboxer style).
  lookup = Messaging::Mailers::MessageMailer.new.lookup_context
  %w[new_message_email reply_message_email add_participant_email].each do |tpl|
    h.check("Messaging mailer template #{tpl}", lookup.exists?(tpl, [Messaging::Mailers::MessageMailer.mailer_name], false), true)
  end

  # --- B-NOT: notifications -----------------------------------------------
  puts '-- B-NOT notifications'
  recipient = h.user('notified', active: true)
  actor = h.user('actor', active: true)
  partials = Dir[Rails.root.join('app/components/notification_center/notifications/*/_*.html.slim')]
  h.check('notification partials present', partials.size, 11..)
  distinct = NotificationCenter::NotificationRecord.unscoped.distinct.pluck(:notifiable_type, :action)
  h.info('distinct (type, action) pairs in this database', distinct.size.to_s)
  rendered = 0
  failures = []
  distinct.each do |type, action|
    record = NotificationCenter::NotificationRecord.where(notifiable_type: type, action: action).includes(:notifiable, :actor).order(id: :desc).detect(&:notifiable)
    next unless record

    begin
      NotificationCenter::Notification.from_record(record)
      rendered += 1
    rescue StandardError => e
      failures << "#{type}/#{action}: #{e.class}"
    end
  end
  h.check('every stored notification type/action pair renders', failures, [])
  h.info('notification pairs rendered', rendered.to_s)
  sample = NotificationCenter::NotificationRecord.where.not(notifiable_type: nil).detect(&:notifiable)
  if sample
    NotificationCenter::NotificationRecord.create!(recipient_id: recipient.id, actor_id: actor.id,
                                                   notifiable: sample.notifiable, action: sample.action)
    res = as.('notified', recipient).get('/notifications')
    h.check_status('GET /notifications as recipient', res, 200)
    h.check('notification JSON lists the new notification', JSON.parse(res.body).size, 1..)
    h.check_status('mark_as_read', as.('notified', recipient).post('/notifications/mark_as_read'), 200)
    h.check('all notifications read', NotificationCenter::NotificationRecord.where(recipient_id: recipient.id, read_at: nil).count, 0)
  else
    h.info('notification create/list', 'no existing notifiable in this DB to attach a throwaway notification to')
  end
  h.check_status('anonymous /notifications is redirected to sign-in', h.client('fresh-anon').get('/notifications'), [302, 401])

  # --- B-MSG: messaging -----------------------------------------------------
  puts '-- B-MSG messaging'
  h.check_status('/wiadomosci renders for a member', as.('notified', recipient).get('/wiadomosci'), 200)
  h.check_status('/wiadomosci for anonymous is not 200', h.client('fresh-anon').get('/wiadomosci'), [302, 401])

  # --- B-PAY: Dotpay -----------------------------------------------------------
  puts '-- B-PAY Dotpay callback'
  code = SecureRandom.hex(13)
  payment = Db::Payment.create!(dotpay_id: code)
  h.check('new payment starts unpaid', payment.reload.state, 'unpaid')
  not_done = anon.post('/api/payments/status', params: { control: code, operation_status: 'rejected' })
  h.check_status('status callback with rejected answers 200', not_done, 200)
  h.check('rejected callback leaves payment unpaid', payment.reload.state, 'unpaid')
  done = anon.post('/api/payments/status', params: { control: code, operation_status: 'completed' })
  h.check_status('status callback completed answers 200', done, 200)
  h.check('completed callback body is OK', done.body, 'OK')
  h.check('completed callback marks payment prepaid', payment.reload.state, 'prepaid')
  replay = anon.post('/api/payments/status', params: { control: code, operation_status: 'completed' })
  h.check('replayed callback is idempotent (OK, still prepaid)', [replay.status, replay.body, payment.reload.state], [200, 'OK', 'prepaid'])
  unknown = anon.post('/api/payments/status', params: { control: 'does-not-exist', operation_status: 'completed' })
  h.check_status('callback for an unknown control does not 500', unknown, [200, 404])
  forged_code = SecureRandom.hex(13)
  forged = Db::Payment.create!(dotpay_id: forged_code)
  anon.post('/api/payments/status', params: { control: forged_code, operation_status: 'completed', signature: 'bogus' })
  h.check('SECURITY: unsigned callback must NOT mark a payment paid (no signature check exists)', forged.reload.state, 'unpaid')
  h.check_status('thank_you with status=OK redirects to /payments', anon.post('/api/payments/thank_you', params: { status: 'OK' }), 302)
  cash_payment = Db::Payment.create!(dotpay_id: SecureRandom.hex(13))
  anon_paid = h.client('fresh-anon').put("/payments/#{cash_payment.id}/mark_as_paid")
  h.check_status('anonymous mark_as_paid is redirected back', anon_paid, [302, 303])
  h.check('anonymous mark_as_paid left the payment unpaid', cash_payment.reload.state, 'unpaid')
  cash_user = h.user('events', roles: %w[events])
  as.('events', cash_user).put("/payments/#{cash_payment.id}/mark_as_paid")
  h.check('events role mark_as_paid sets cash + prepaid', [cash_payment.reload.cash, cash_payment.state], [true, 'prepaid'])
  s = Rails.application.secrets
  %i[dotpay_base_url dotpay_login dotpay_password dotpay_fees_id dotpay_reservations_id dotpay_trainings_id
     dotpay_donations_id dotpay_donations_other_id dotpay_club_trips_id dotpay_back_url].each do |name|
    h.check("secret #{name} is present", s.public_send(name).to_s.length, 1..)
  end
  h.info('dotpay_base_url host', URI.parse(s.dotpay_base_url.to_s).host.to_s)
  h.info('dotpay_urlc (URL Dotpay posts to) host', URI.parse(s.dotpay_urlc.to_s).host.to_s) if s.dotpay_urlc.present?

  # --- B-MAIL-4 / B-MAIL-5: Mailgun delivery webhook and inbound reply ---------
  puts '-- B-MAIL webhook + inbound reply'
  mail_id = "<stg-check-#{SecureRandom.hex(6)}@example.invalid>"
  rec = EmailCenter::EmailRecord.create!(message_id: mail_id, mailable_id: profile&.id || 1, mailable_type: 'Db::Profile')
  hook = anon.post('/api/emails/delivered', params: { 'event-data' => { 'message' => { 'headers' => { 'message-id' => mail_id } } } })
  h.check_status('delivered webhook answers 200 for a known message-id', hook, 200)
  h.check('delivered webhook sets delivered_at', rec.reload.delivered_at.present?, true)
  h.check_status('delivered webhook answers 404 for an unknown message-id',
                 anon.post('/api/emails/delivered', params: { 'event-data' => { 'message' => { 'headers' => { 'message-id' => 'nope' } } } }), 404)

  replier = h.user('replier', active: true)
  receipt = nil
  uses_emails = Mailboxer.uses_emails
  Mailboxer.uses_emails = false # create the conversation without rendering its mail; rendering is checked separately
  receipt = actor.send_message(replier, 'first message', 'smoke subject')
  Mailboxer.uses_emails = uses_emails
  conversation = receipt&.conversation
  h.check('Mailboxer::Conversation extensions loaded (sign_ups, courses association)',
          %i[sign_ups courses].map { |a| Mailboxer::Conversation.reflect_on_association(a).present? }, [true, true])
  attempt.call('new-message e-mail renders (Messaging::Mailers::MessageMailer)', true) do
    Messaging::Mailers::MessageMailer.new_message_email(receipt.message, replier).message.parts.map { |part| part.body.to_s.length }.all?(&:positive?)
  end
  h.check('conversation created with a code', conversation&.code.to_s.length, 1..)
  if conversation&.code
    before_msgs = conversation.messages.count
    inbound = anon.post('/email_processor', params: {
                          to: "Panel KW <reply+#{conversation.code}@panel.kw.krakow.pl>", from: replier.email, subject: 'Re: smoke subject',
                          text: 'reply by e-mail', headers: '', charsets: '{}', envelope: '{}'
                        })
    h.check_status('inbound /email_processor accepts a SendGrid-format reply', inbound, 200)
    h.check('inbound reply was added to the conversation', conversation.reload.messages.count - before_msgs, 1)
  end

  # --- B-STR: Strava webhook ---------------------------------------------------
  puts '-- B-STR Strava webhook verification'
  token = s.strava_verify_token.to_s
  h.check('strava_verify_token is present', token.length, 1..)
  ok = anon.get('/activities/api/strava_activities/callback',
                params: { 'hub.mode' => 'subscribe', 'hub.verify_token' => token, 'hub.challenge' => 'abc123' })
  h.check_status('valid verify_token answers 200', ok, 200)
  h.check('challenge is echoed back', ok.body, /abc123/)
  bad = anon.get('/activities/api/strava_activities/callback',
                 params: { 'hub.mode' => 'subscribe', 'hub.verify_token' => 'wrong', 'hub.challenge' => 'abc123' })
  h.check('wrong verify_token is not accepted', bad.status == 200 && bad.body.include?('abc123'), false)

  # --- B-SEC: other secrets (presence only) ----------------------------------
  puts '-- B-SEC secrets present'

  h.check('mailgun api key is configured', Rails.application.config.action_mailer.mailgun_settings&.dig(:api_key).to_s.length, 1..)
  h.check('mailgun domain is configured', Rails.application.config.action_mailer.mailgun_settings&.dig(:domain).to_s.length, 1..)
  h.info('mailgun domain', Rails.application.config.action_mailer.mailgun_settings&.dig(:domain).to_s)
  h.check('openstack username configured', Rails.application.credentials.dig(:openstack, :username).to_s.length, 1..)
  h.check('openstack api key configured', Rails.application.credentials.dig(:openstack, :api_key).to_s.length, 1..)
  h.check('secret_key_base present', Rails.application.secret_key_base.to_s.length, 30..)
  h.info('action_mailer default host', Rails.application.config.action_mailer.default_url_options.inspect)
  h.info('routes default host', Rails.application.routes.default_url_options.inspect)
  h.info('force_ssl', Rails.application.config.force_ssl.inspect)
  h.info('hosts allow-list size', Rails.application.config.hosts.to_a.size.to_s)

  # --- B-FIL: OpenStack read-only -------------------------------------------
  puts '-- B-FIL OpenStack (read-only)'
  attempt.call('OpenStack token + container reachable', true) do
    storage = Fog::Storage.new(CarrierWave::Uploader::Base.fog_credentials)
    dir = storage.directories.get(CarrierWave::Uploader::Base.fog_directory)
    h.info('container', "#{CarrierWave::Uploader::Base.fog_directory} (#{dir ? 'found' : 'NOT FOUND'})")
    dir.present?
  end
  stored = Db::Profile.where.not(photo: [nil, '']).first || Db::Profile.where.not(course_cert: [nil, '']).first
  if stored
    # Staging has its own (empty) container; restored rows point at files in the production container.
    # The production container is only read here (anonymous HEAD), never written.
    head = lambda do |url|
      uri = URI.parse(url)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 15, read_timeout: 15) { |http| http.head(uri.request_uri) }.code.to_i
    end
    attempt.call('an existing stored file answers a HEAD request on its URL (production container, anonymous)', 200) do
      url = (stored.photo.present? ? stored.photo : stored.course_cert).url
      h.info('stored-file URL host', URI.parse(url).host.to_s)
      own = head.call(url)
      h.info('stored-file HEAD in this env container', own.to_s)
      own == 200 ? own : head.call(url.sub(%r{/kw-app-cloud-[a-z]+/}, '/kw-app-cloud-production/'))
    end
  else
    h.info('stored file HEAD (NOT TESTABLE: no uploaded file in this database)', 'run again after a prod restore')
  end

  # --- B-CRN / B-ADR: code gaps found in the cron review (G16, G17) -----------
  puts '-- B-CRN cron code paths'
  g16 = %w[
    Training::Supplementary::FillEmptyPlaces Training::Supplementary::DestroySignUp
    Training::Supplementary::OpenConversation Training::Supplementary::AddToConversation
    Training::Supplementary::SendEmailWithPayment Training::Questionare::SnwProfileService
    Events::Competitions::SignUps::Destroy
  ]
  g16.each do |name|
    klass = name.safe_constantize
    h.check("G16 #{name} exists and includes Dry::Monads",
            !klass.nil? && klass.ancestors.any? { |a| a.name.to_s.start_with?('Dry::Monads') }, true)
  end
  sql = Training::Supplementary::Repository.new.expired_sign_ups.to_sql
  h.info('G17 expired_sign_ups SQL', sql[/WHERE.*/m].to_s[0, 240])
  h.check('G17 expired_sign_ups is not a NOT(a AND b) predicate', sql =~ /NOT \([^)]*AND/i, nil)
  Rails.application.load_tasks
  %w[send_prepaid_emails send_reminders send_yearly_fee_reminder destroy_unpaid_reservations destroy_outdated_profiles destroy_expired_sign_ups destroy_expired_events_sign_ups].each do |t|
    h.check("rake task #{t} is defined", Rake::Task.task_defined?(t), true)
  end
  h.info('cron TZ of this process', "#{Time.zone.name} / ENV TZ=#{ENV['TZ'].inspect}")

  # --- B-JOB: Redis / Sidekiq (informational on staging) -------------------
  puts '-- B-JOB Redis / Sidekiq'
  begin
    pong = Sidekiq.redis { |c| c.ping }
    h.check('Sidekiq Redis answers PING', pong, 'PONG')
    h.check('a Sidekiq worker process is alive (job role running)', Sidekiq::ProcessSet.new.size, 1..)
    h.info('Sidekiq queues (name=size)', Sidekiq::Queue.all.map { |q| "#{q.name}=#{q.size}" }.join(' '))
    h.info('Sidekiq retry/dead/scheduled', "#{Sidekiq::RetrySet.new.size}/#{Sidekiq::DeadSet.new.size}/#{Sidekiq::ScheduledSet.new.size}")
  rescue StandardError => e
    h.info('Sidekiq Redis (NOT REACHABLE)', "#{e.class}: #{e.message[0, 80]}")
  end
  # master sets :sidekiq in config/application.rb; the Rails 6.1 upgrade dropped it (G25)
  h.check('ActiveJob adapter is :sidekiq (as on old prod)', Rails.application.config.active_job.queue_adapter, :sidekiq)
  h.check_status('anonymous /sidekiq is not served', h.client('fresh-anon').get('/sidekiq'), [302, 401, 404])
  h.check_status('plain member /sidekiq is not served', as.('notified', recipient).get('/sidekiq'), [302, 401, 403, 404])
  admin_ui = as.('admin', admin).get('/sidekiq')
  h.check_status('admin /sidekiq opens', admin_ui, [200, 301, 302])
end
