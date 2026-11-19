# frozen_string_literal: true

# Scenario: Training::Supplementary courses, sign-ups and payments (B-CRS, B-SUP, B-PAY-cash/callback).
# Run together with harness.rb (see SKILL.md). Everything happens in one rolled-back transaction as throwaway
# users; mail is rendered with the :test delivery method and never sent. Dotpay is NOT called: the charge
# redirect and refund hit the Dotpay API and are covered by the manual rows of Appendix B.
#
# `known_gap` lines are documented findings (G24 courses without authorization, G25 sign-up edit/update/manually,
# G26 denied branches raise, G23 unsigned callback). They print GAP and do not fail the run.

StagingHarness.run('Training::Supplementary courses, sign-ups, payments') do |h|
  Course = Training::Supplementary::CourseRecord unless defined?(Course)
  SignUp = Training::Supplementary::SignUpRecord unless defined?(SignUp)

  admin  = h.user('admin', roles: %w[admin], active: true)
  events = h.user('events', roles: %w[events], active: true)
  member = h.user('member', active: true)
  guest_email = "stg-check+guest-#{SecureRandom.hex(3)}@example.invalid"

  anon = h.client
  as = ->(label, user) { h.client(label, user) }

  make_course = lambda do |**attrs|
    Course.create!({
      name: "stg-check course #{SecureRandom.hex(3)}", place: 'Kraków', state: :published,
      payment_type: :trainings, price_kw: 150, start_date: 2.weeks.from_now, end_date: 2.weeks.from_now + 1.day
    }.merge(attrs))
  end
  course = make_course.call

  # --- B-CRS: public pages ---------------------------------------------------
  puts '-- B-CRS public pages'
  h.check_status('/wydarzenia for anonymous redirects, no 500', anon.get('/wydarzenia'), [302, 401])
  list = as.('member', member).get('/wydarzenia')
  h.check_status('/wydarzenia renders for a member', list, 200)
  h.check('/wydarzenia lists the published course', list.body.include?(course.name), true)
  show = as.('member', member).get("/wydarzenia/#{course.slug}")
  h.check_status('course page by slug renders', show, 200)
  h.check('course page shows the course name', show.body.include?(course.name), true)
  h.check_status('unknown slug redirects, no 500', as.('member', member).get('/wydarzenia/stg-check-does-not-exist'), [302, 404])
  h.check_status('archived list renders', as.('member', member).get('/supplementary/courses/archived'), 200)
  h.check_status('category filter renders', as.('member', member).get('/wydarzenia/wspinaczkowe'), 200)

  # --- B-CRS: management -----------------------------------------------------
  puts '-- B-CRS management (events role)'
  mgr = as.('events', events)
  h.check_status('admin list renders', mgr.get('/supplementary/courses'), 200)
  h.check_status('new form renders', mgr.get('/supplementary/courses/new'), 200)
  h.check_status('edit form renders', mgr.get("/supplementary/courses/#{course.id}/edit"), 200)

  before = Course.count
  created = mgr.post('/supplementary/courses', params: { course: { name: "stg-check created #{SecureRandom.hex(3)}", place: 'Tatry',
                                                                     payment_type: 'trainings', kind: 'training', category: 'kw', state: 'draft' } })
  h.check_status('create redirects', created, 302)
  h.check('create adds one course', Course.count, before + 1)
  invalid = mgr.post('/supplementary/courses', params: { course: { name: '', place: '', payment_type: 'trainings' } })
  h.check_status('invalid create re-renders the form', invalid, 200)
  h.check('invalid create adds nothing', Course.count, before + 1)

  versions = PaperTrail::Version.where(item_type: 'Training::Supplementary::CourseRecord', item_id: course.id).count
  h.check_status('update redirects', mgr.patch("/supplementary/courses/#{course.id}", params: { course: { name: 'stg-check renamed' } }), 302)
  h.check('update persisted', course.reload.name, 'stg-check renamed')
  h.check('update wrote a PaperTrail version', PaperTrail::Version.where(item_type: 'Training::Supplementary::CourseRecord', item_id: course.id).count, versions + 1)
  %w[draft cancelled archived published].each do |state|
    mgr.patch("/supplementary/courses/#{course.id}", params: { course: { state: state } })
    h.check("state -> #{state}", course.reload.state, state)
  end
  xlsx = mgr.get("/supplementary/courses/#{course.id}.xlsx")
  h.check_status('sign-up list xlsx export', xlsx, 200)
  h.check('xlsx content type', xlsx.content_type.to_s, /spreadsheet/)

  puts '-- B-CRS authorization (G24)'
  victim = make_course.call(name: "stg-check victim #{SecureRandom.hex(3)}")
  count = Course.count
  anon.post('/supplementary/courses', params: { course: { name: 'stg-check anon', place: 'X', payment_type: 'trainings' } })
  h.known_gap('G24', 'anonymous cannot create a course', Course.count, count)
  anon.patch("/supplementary/courses/#{victim.id}", params: { course: { name: 'stg-check hacked' } })
  h.known_gap('G24', 'anonymous cannot rename a course', victim.reload.name.start_with?('stg-check victim'), true)
  as.('member', member).delete("/supplementary/courses/#{victim.id}")
  h.known_gap('G24', 'plain member cannot destroy a course', Course.exists?(victim.id), true)
  mgr.delete("/supplementary/courses/#{victim.id}")
  h.check('events user destroys a course', Course.exists?(victim.id), false)

  # --- B-SUP: signing up -----------------------------------------------------
  puts '-- B-SUP member sign-up and payment record'
  signup_params = { sign_up: { name: member.display_name, email: member.email, user_id: member.id.to_s, course_id: course.id.to_s } }
  deliveries = h.capture_mail { as.('member', member).post('/supplementary/sign_ups', params: signup_params) }
  sign_up = SignUp.find_by(course_id: course.id, user_id: member.id)
  h.check('member sign-up created', sign_up.present?, true)
  h.check('payment created unpaid with a dotpay id', [sign_up&.payment&.state, sign_up&.payment&.dotpay_id.to_s.length > 5], ['unpaid', true])
  h.check('payment is attached to the sign-up', sign_up&.payment&.payable, sign_up)
  h.check('cost comes from the course price', sign_up&.cost, 150)
  h.check('payment-link mail was rendered and addressed to the member', deliveries.map { |m| m.to.to_a }.flatten, [member.email])
  h.check('payment-link mail has a body', deliveries.first&.body.to_s.length, 50..)
  h.check('sent_at stamped', sign_up&.sent_at.present?, true)

  count = SignUp.count
  as.('member', member).post('/supplementary/sign_ups', params: signup_params)
  h.check('second sign-up with the same email is refused', SignUp.count, count)

  guest_params = { sign_up: { name: 'Stg Guest', email: guest_email, course_id: course.id.to_s } }
  as.('anon', nil).post('/supplementary/sign_ups', params: guest_params)
  guest = SignUp.find_by(email: guest_email)
  h.check('guest (no account) can sign up', guest.present?, true)

  puts '-- B-SUP Dotpay callback marks the sign-up prepaid'
  pay = sign_up.payment
  done = anon.post('/api/payments/status', params: { control: pay.dotpay_id, operation_status: 'completed' })
  h.check('callback answers OK', [done.status, done.body], [200, 'OK'])
  h.check('sign-up payment is prepaid', pay.reload.state, 'prepaid')
  h.check('course income counts the sign-up', course.reload.income_sum, 150)
  h.check('limiter counts it as prepaid', Training::Supplementary::Limiter.new(course).sum, 1)

  puts '-- B-SUP admin paths (events role)'
  manual_email = "stg-check+manual-#{SecureRandom.hex(3)}@example.invalid"
  manual_mail = h.capture_mail do
    mgr.put('/supplementary/sign_ups/manually',
            params: { manually_sign_up: { name: 'Stg Manual', email: manual_email, course_id: course.id.to_s, link_payment: '1' } })
  end
  manual = SignUp.find_by(email: manual_email)
  h.check('manual sign-up created with the admin recorded', [manual.present?, manual&.admin_id], [true, events.id])
  h.check('manual sign-up sent the payment link', manual_mail.size, 1)

  mail_for_guest = h.capture_mail { mgr.put("/supplementary/sign_ups/#{guest.id}/send_email") }
  h.check('send_email rendered one mail', mail_for_guest.size, 1)
  h.check('send_email stamped the sender', guest.reload.sent_user_id, events.id)

  guest_pay = guest.payment
  mgr.put("/payments/#{guest_pay.id}/mark_as_paid")
  h.check('cash payment: prepaid and cash', [guest_pay.reload.state, guest_pay.cash, guest_pay.cash_user_id], ['prepaid', true, events.id])
  mgr.put("/supplementary/sign_ups/#{guest.id}/cancel_cash_payment")
  h.check('cancel cash payment: back to unpaid', [guest_pay.reload.state, guest_pay.cash], ['unpaid', false])
  h.check_status('sign-up edit form renders', mgr.get("/supplementary/sign_ups/#{guest.id}/edit"), 200)

  puts '-- B-SUP public cancel link'
  h.check_status('unknown cancel code redirects, no 500', anon.get('/wydarzenie/wypisz/stg-check-nope'), 302)
  count = SignUp.count
  cancel = anon.get("/wydarzenie/wypisz/#{guest.code}")
  h.check_status('cancel link redirects', cancel, 302)
  h.check('cancel link removed the sign-up and its payment', [SignUp.count, Db::Payment.exists?(guest_pay.id)], [count - 1, false])

  puts '-- B-SUP destroy by events user'
  count = SignUp.count
  mgr.delete("/supplementary/sign_ups/#{manual.id}")
  h.check('events user destroys a sign-up', SignUp.count, count - 1)

  puts '-- B-SUP authorization (G25, G26)'
  other = Training::Supplementary::Repository.new.sign_up!(name: 'Stg Other', email: "stg-check+other-#{SecureRandom.hex(3)}@example.invalid",
                                                          user_id: nil, course_id: course.id, question: nil)
  plain = as.('member', member)
  count = SignUp.count
  plain.put('/supplementary/sign_ups/manually',
            params: { manually_sign_up: { name: 'Stg Intruder', email: "stg-check+intruder-#{SecureRandom.hex(3)}@example.invalid", course_id: course.id.to_s } })
  h.known_gap('G25', 'plain member cannot sign somebody up manually', SignUp.count, count)
  plain.put("/supplementary/sign_ups/#{other.id}", params: { sign_up: { name: 'Hacked', email: other.email, course_id: course.id.to_s } })
  h.known_gap('G25', "plain member cannot change somebody else's sign-up", other.reload.name, 'Stg Other')
  res = plain.put("/supplementary/sign_ups/#{other.id}/send_email")
  h.known_gap('G26', 'plain member send_email is denied cleanly (no exception)', res.exception.nil?, true)
  res = plain.delete("/supplementary/sign_ups/#{other.id}")
  h.known_gap('G26', 'plain member destroy is denied cleanly (no exception)', res.exception.nil?, true)

  puts '-- B-SUP expiry (cron destroy_expired_sign_ups)'
  expired = Training::Supplementary::Repository.new.sign_up!(name: 'Stg Expired', email: "stg-check+exp-#{SecureRandom.hex(3)}@example.invalid",
                                                            user_id: nil, course_id: course.id, question: nil)
  expired.update!(sent_at: 3.days.ago, expired_at: 1.day.ago)
  candidates = Training::Supplementary::Repository.new.expired_sign_ups.to_a
  h.check('expired unpaid sign-up is a cron candidate', candidates.map(&:id).include?(expired.id), true)
  h.check('a paid sign-up is never a candidate', candidates.map(&:id).include?(sign_up.id), false)
  Training::Supplementary::Workers::DestroyExpiredSignUpWorker.new.perform(expired.id)
  h.check('the worker removes the expired sign-up', SignUp.exists?(expired.id), false)
  h.check('prepaid mails selection runs', Training::Supplementary::SendPrepaidEmail.new.candidates.to_a.size, Integer)

  puts '-- B-PAY callback edge cases'
  rej = SignUp.find(other.id).payment
  r = anon.post('/api/payments/status', params: { control: rej.dotpay_id, operation_status: 'rejected' })
  h.check('rejected callback echoes the status and stays unpaid', [r.body, rej.reload.state], ['rejected', 'unpaid'])
  unknown = anon.post('/api/payments/status', params: { control: 'stg-check-unknown', operation_status: 'completed' })
  h.known_gap('G23b', 'unknown control answers 200/404, not 500', unknown.status, [200, 404])
  forged = Training::Supplementary::Repository.new.sign_up!(name: 'Stg Forged', email: "stg-check+forged-#{SecureRandom.hex(3)}@example.invalid",
                                                           user_id: nil, course_id: course.id, question: nil).payment
  anon.post('/api/payments/status', params: { control: forged.dotpay_id, operation_status: 'completed', signature: 'bogus' })
  h.known_gap('G23', 'unsigned callback does not mark a payment paid', forged.reload.state, 'unpaid')
end
