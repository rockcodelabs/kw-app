# frozen_string_literal: true

# Scenario: gear reservation module (B-RES-1..3): member availability and booking, double-booking refusal,
# cancelling (own vs somebody else's), keeper (reservations role) admin actions, the unpaid-cleanup cron.
# Run together with harness.rb (see SKILL.md). Everything happens in one rolled-back transaction with throwaway
# users and throwaway items named `stg-check ...`, so real items and reservations are never touched.
# Mail is rendered with the :test delivery method and never sent. Dotpay is NOT called.

StagingHarness.run('Reservations module') do |h|
  routes = h.routes
  keeper  = h.user('keeper', roles: %w[reservations], active: true)
  member  = h.user('member', active: true)
  other   = h.user('other', active: true)
  anon    = h.client
  as      = ->(label, user) { h.client(label, user) }

  start_date = Date.current.next_occurring(:thursday)
  end_date   = start_date.next_week(:thursday)

  make_item = lambda do |label|
    Db::Item.create!(display_name: "stg-check item #{label} #{SecureRandom.hex(3)}", rentable: true, owner: :kw)
  end
  make_reservation = lambda do |user, items, **attrs|
    Db::Reservation.create!({ user: user, start_date: start_date, end_date: end_date, state: 'reserved' }.merge(attrs)).tap do |r|
      r.items << items
      r.create_payment!(dotpay_id: SecureRandom.hex(13))
    end
  end
  book = lambda do |client, item, from: start_date, to: end_date|
    client.post(routes.reservations_path, params: { reservations_form: { start_date: from.to_s, end_date: to.to_s, item_ids: [item.id.to_s] } })
  end

  item_a = make_item.call('a')
  item_b = make_item.call('b')
  item_c = make_item.call('c')
  item_d = make_item.call('d')
  item_e = make_item.call('e')

  # --- B-RES-1: member side -------------------------------------------------
  puts '-- B-RES member availability'
  h.check_status('anonymous is sent to login, no 500', anon.get(routes.reservations_path(start_date: start_date.to_s)), [302, 401])
  mem = as.('member', member)
  h.check_status('non-Thursday date redirects to the nearest Thursday', mem.get(routes.reservations_path(start_date: (start_date + 1.day).to_s)), 302)
  past = mem.get(routes.reservations_path(start_date: Date.current.prev_occurring(:thursday).to_s))
  h.check('past date is refused with a redirect', [past.status, past.exception.nil?], [302, true])
  list = mem.get(routes.reservations_path(start_date: start_date.to_s))
  h.check_status('availability page renders for a Thursday', list, 200)
  h.check('availability page lists a free item', list.body.include?(item_a.display_name), true)
  chosen = mem.post(routes.availability_reservations_path, params: { availability_form: { start_date: start_date.to_s } })
  h.check('availability form redirects to the chosen week', [chosen.status, chosen.location.to_s.include?("start_date=#{start_date}")], [302, true])
  h.check_status('/zarezerwuj renders', mem.get('/zarezerwuj'), [200, 302])

  puts '-- B-RES booking'
  book.call(mem, item_a)
  reservation = Db::Reservation.find_by(user_id: member.id)
  h.check('booking creates one reservation owned by the member', [reservation.present?, reservation&.items.to_a], [true, [item_a]])
  h.check('payment created unpaid with a dotpay id', [reservation&.payment&.state, reservation&.payment&.dotpay_id.to_s.length > 5], ['unpaid', true])
  h.check('reservation stays in state reserved', reservation&.state, 'reserved')
  book.call(mem, item_b)
  h.check('a second item joins the same reservation', [Db::Reservation.where(user_id: member.id).count, reservation.reload.items.to_a.sort_by(&:id)], [1, [item_a, item_b]])


  puts '-- B-RES double booking (G30) and invalid week'
  make_reservation.call(other, [item_c])
  h.check('availability no longer offers an item booked by somebody else',
          mem.get(routes.reservations_path(start_date: start_date.to_s)).body.include?(item_c.display_name), false)
  before = Db::Reservation.where(user_id: member.id).count
  taken = book.call(mem, item_c)
  h.check('item reserved by somebody else is refused', [Db::Reservation.where(user_id: member.id).count, taken.exception.nil?], [before, true])
  h.check('refusal redirects back to the week', taken.location.to_s.include?('/reservations'), true)
  book.call(mem, item_d, to: end_date + 7.days)
  h.check('end date not one week after start is refused', Db::Reservation.joins(:items).where(user_id: member.id, items: { id: item_d.id }).count, 0)

  puts '-- B-RES cancelling'
  foreign = Db::Reservation.find_by(user_id: other.id)
  mem.delete(routes.delete_item_reservation_path(foreign), params: { item_id: item_c.id })
  h.check("G35: a member cannot cancel another member's item", foreign.reload.items.to_a, [item_c])
  as.('keeper', keeper).delete(routes.delete_item_reservation_path(foreign), params: { item_id: item_c.id })
  h.check('the keeper can cancel an item of somebody else (last item removes the reservation)', Db::Reservation.exists?(foreign.id), false)

  mem.delete(routes.delete_item_reservation_path(reservation), params: { item_id: item_a.id })
  h.check('member cancels own item', reservation.reload.items.to_a, [item_b])
  payment_id = reservation.payment.id
  mem.delete(routes.delete_item_reservation_path(reservation), params: { item_id: item_b.id })
  h.check('cancelling the last item removes the reservation and its payment',
          [Db::Reservation.exists?(reservation.id), Db::Payment.exists?(payment_id)], [false, false])
  unknown = mem.delete(routes.delete_item_reservation_path(id: 0), params: { item_id: item_a.id })
  h.check('cancelling in an unknown reservation is handled, no exception', unknown.exception.nil?, true)

  # --- B-RES-2: keeper side -------------------------------------------------
  puts '-- B-RES keeper (reservations role)'
  keep = as.('keeper', keeper)
  target = make_reservation.call(member, [item_e])
  h.check_status('admin list renders', keep.get(routes.admin_reservations_path), 200)
  h.check_status('admin edit form renders', keep.get(routes.edit_admin_reservation_path(target)), 200)
  xlsx = keep.get(routes.admin_reservations_path(format: :xlsx))
  h.check_status('xlsx export', xlsx, 200)
  h.check('xlsx content type', xlsx.content_type.to_s, /spreadsheet/)

  reminders = h.capture_mail { keep.post(routes.remind_admin_reservation_path(target)) }
  h.check('reminder mail rendered and addressed to the member', reminders.map { |m| m.to.to_a }.flatten, [member.email])
  h.check('reminder mail has a body', reminders.first&.body.to_s.length, 50..)

  keep.post(routes.give_warning_admin_reservation_path(target))
  h.check('warning added', member.reload.warnings, 1)
  keep.post(routes.give_back_warning_admin_reservation_path(target))
  h.check('warning removed', member.reload.warnings, 0)

  keep.put(routes.charge_admin_reservation_path(target))
  h.check('charge marks the payment as paid in cash', target.payment.reload.cash, true)

  given = make_reservation.call(member, [item_e])
  keep.put(routes.give_admin_reservation_path(given))
  h.check('give changes the state from reserved', given.reload.state == 'reserved', false)

  archived = make_reservation.call(member, [item_e])
  keep.put(routes.archive_admin_reservation_path(archived))
  h.check('archive sets the state archived', archived.reload.state, 'archived')

  doomed = make_reservation.call(member, [item_e])
  keep.delete(routes.admin_reservation_path(doomed))
  h.check('keeper destroys a reservation', Db::Reservation.exists?(doomed.id), false)

  puts '-- B-RES admin authorization'
  guarded = make_reservation.call(other, [item_e])
  plain = as.('member', member)
  h.check_status('plain member admin list is not a 500', plain.get(routes.admin_reservations_path), [200, 302, 403])
  plain.put(routes.give_admin_reservation_path(guarded))
  plain.put(routes.archive_admin_reservation_path(guarded))
  plain.delete(routes.admin_reservation_path(guarded))
  h.check('no-role member cannot give, archive or destroy', [Db::Reservation.exists?(guarded.id), guarded.reload.state], [true, 'reserved'])
  denied_list = plain.get(routes.admin_reservations_path)
  h.check_denied('no-role member is denied the admin list', denied_list)

  # --- B-RES-3: unpaid cleanup (cron destroy_unpaid_reservations), read-only on real data -------------
  puts '-- B-RES unpaid cleanup candidates'
  old_unpaid = make_reservation.call(member, [item_e], created_at: 3.days.ago)
  old_cash   = make_reservation.call(other, [item_e], created_at: 3.days.ago)
  old_cash.payment.update!(cash: true, state: 'prepaid')
  fresh = make_reservation.call(keeper, [item_e])
  candidate_ids = Reservations::Workers::DestroyUnpaidReservationsWorker.candidates.map(&:id)
  h.check('old unpaid reservation is a cron candidate', candidate_ids.include?(old_unpaid.id), true)
  h.check('cash-paid reservation is never a candidate', candidate_ids.include?(old_cash.id), false)
  h.check('fresh reservation is never a candidate', candidate_ids.include?(fresh.id), false)
end
