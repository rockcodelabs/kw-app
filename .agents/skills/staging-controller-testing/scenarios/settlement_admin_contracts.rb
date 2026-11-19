# frozen_string_literal: true

# Scenario: Settlement::Admin::ContractsController
# Run together with harness.rb (see SKILL.md). Expectations describe the
# INTENDED behaviour (per Ability + UI), so a FAIL is either a controller bug
# or a wrong expectation - investigate before "fixing" the check.

StagingHarness.run('Settlement::Admin::ContractsController') do |h|
  r = h.routes

  # --- fixtures -----------------------------------------------------------
  office_king = h.user('office_king', roles: %w[office_king])
  financial   = h.user('financial', roles: %w[financial_management])
  secondary   = h.user('secondary', roles: %w[secondary_management])
  admin       = h.user('admin', roles: %w[admin])
  member      = h.user('member', active: true)
  other       = h.user('other', active: true)
  outsider    = h.user('outsider') # not active, no roles

  contractor = Settlement::ContractorRecord.create!(name: 'Stg Check Contractor')
  period = Date.new(Date.current.year, 1, 1)
  seq = 90_000

  make_contract = lambda do |creator: member, state: 'new', typed: true, **attrs|
    seq += 1
    base = {
      title: "stg-check contract #{seq}", creator_id: creator.id, contractor_id: contractor.id,
      cost: 10, currency_type: 'pln', document_type: 'charities', payout_type: 'to_contractor',
      document_date: Date.current, period_date: period, internal_number: seq, state: state,
      user_ids: [creator.id]
    }
    base.merge!(activity_type: 'other_activity', group_type: 'kw', event_type: 'not_event') if typed
    Settlement::ContractRecord.create!(base.merge(attrs))
  end

  valid_update = {
    contract: { title: 'Updated by check', cost: '20.5', document_type: 'charities', payout_type: 'to_contractor',
                currency_type: 'pln', document_date: Date.current.to_s, document_number: 'FV/STG/1', description: 'd' }
  }
  valid_create = {
    contract: { title: 'Created by check', contractor_id: contractor.id.to_s, group_type: 'kw',
                document_number: 'FV/STG/2', document_date: Date.current.to_s, document_type: 'charities',
                payout_type: 'to_contractor', currency_type: 'pln', cost: '10.5', description: 'd',
                user_ids: [member.id.to_s] }
  }

  anon = h.client
  c = ->(label, user) { h.client(label, user) }

  # --- index --------------------------------------------------------------
  puts '-- index'
  h.check_denied('anonymous cannot list', anon.get(r.admin_contracts_path))
  h.check_status('outsider (no create/read grant) can open list or is redirected', c.('outsider', outsider).get(r.admin_contracts_path), [200, 302])
  h.check_status('active member lists contracts', c.('member', member).get(r.admin_contracts_path), 200)
  h.check_status('office_king lists contracts', c.('office_king', office_king).get(r.admin_contracts_path), 200)
  xlsx = c.('office_king', office_king).get(r.admin_contracts_path(format: :xlsx))
  h.check_status('office_king exports xlsx', xlsx, 200)
  h.check('xlsx content type', xlsx.content_type.to_s, /spreadsheet/)
  h.check_status('sort by custom_state desc', c.('office_king', office_king).get(r.admin_contracts_path, params: { q: { s: 'custom_state desc' } }), 200)
  h.check_status('malformed sort param does not 500', c.('office_king', office_king).get(r.admin_contracts_path, params: { q: { s: 'custom_state bogus' } }), 200)

  # --- archive / history / analiza ---------------------------------------
  puts '-- archive / history / analiza'
  h.check_denied('anonymous cannot open archive', anon.get(r.archive_admin_contracts_path))
  h.check_status('office_king opens archive', c.('office_king', office_king).get(r.archive_admin_contracts_path), 200)
  h.check_denied('anonymous cannot open history', anon.get(r.history_admin_contracts_path))
  h.check_denied('plain member cannot open history', c.('member', member).get(r.history_admin_contracts_path))
  h.check_status('financial opens history', c.('financial', financial).get(r.history_admin_contracts_path), 200)
  analiza_path = "/rozliczenia/analiza/#{Date.current.year}"
  h.check_denied('anonymous cannot open analiza', anon.get(analiza_path))
  h.check_denied('plain member cannot open analiza', c.('member', member).get(analiza_path))
  h.check_status('admin opens analiza', c.('admin', admin).get(analiza_path), 200)

  # --- new / create -------------------------------------------------------
  puts '-- new / create'
  h.check_denied('anonymous cannot open new', anon.get(r.new_admin_contract_path))
  h.check_denied('outsider cannot open new', c.('outsider', outsider).get(r.new_admin_contract_path))
  h.check_status('active member opens new', c.('member', member).get(r.new_admin_contract_path), 200)

  before = Settlement::ContractRecord.count
  h.check_denied('anonymous cannot create', anon.post(r.admin_contracts_path, params: valid_create))
  h.check('anonymous create persisted nothing', Settlement::ContractRecord.count, before)

  h.clear_enqueued_jobs!
  res = c.('member', member).post(r.admin_contracts_path, params: valid_create)
  h.check_status('member creates contract', res, 302)
  h.check('create redirects to list', res.location.to_s, %r{/admin/contracts\z})
  h.check('create persisted one contract', Settlement::ContractRecord.count, before + 1)
  created = Settlement::ContractRecord.find_by(title: 'Created by check')
  h.check('created contract belongs to member, state new', [created&.creator_id, created&.state], [member.id, 'new'])
  h.check('create enqueued notification mail', h.enqueued_jobs.size, 1..)

  invalid = valid_create.deep_dup.tap { |p| p[:contract][:title] = '' }
  res = c.('member', member).post(r.admin_contracts_path, params: invalid)
  h.check_status('invalid create re-renders form', res, [200, 422])
  h.check('invalid create persisted nothing', Settlement::ContractRecord.count, before + 1)

  # --- show / edit --------------------------------------------------------
  puts '-- show / edit'
  mine = make_contract.call
  h.check_status('creator sees own contract', c.('member', member).get(r.admin_contract_path(mine)), 200)
  h.check_denied('other user cannot see contract', c.('other', other).get(r.admin_contract_path(mine)))
  h.check_denied('anonymous cannot see contract', anon.get(r.admin_contract_path(mine)))
  h.check_status('office_king sees any contract', c.('office_king', office_king).get(r.admin_contract_path(mine)), 200)
  h.check_status('unknown id is handled (redirect)', c.('office_king', office_king).get(r.admin_contract_path(id: 0)), 302)
  h.check_status('creator opens edit', c.('member', member).get(r.edit_admin_contract_path(mine)), 200)
  h.check_denied('other user cannot open edit', c.('other', other).get(r.edit_admin_contract_path(mine)))

  # --- update -------------------------------------------------------------
  puts '-- update'
  res = c.('member', member).put(r.admin_contract_path(mine), params: valid_update)
  h.check_status('creator updates own contract', res, 302)
  h.check('title was updated', mine.reload.title, 'Updated by check')

  theirs = make_contract.call(title: 'untouched')
  res = c.('other', other).put(r.admin_contract_path(theirs), params: valid_update)
  h.check_denied('other user cannot update foreign contract', res)
  h.check('foreign contract title unchanged', theirs.reload.title, 'untouched')

  res = anon.put(r.admin_contract_path(theirs), params: valid_update)
  h.check_denied('anonymous cannot update', res)
  h.check('contract unchanged after anonymous update', theirs.reload.title, 'untouched')

  res = c.('office_king', office_king).put(r.admin_contract_path(theirs), params: { contract: valid_update[:contract].merge(internal_number: '77', user_ids: [member.id.to_s]) })
  h.check_status('office_king updates contract', res, 302)

  res = c.('member', member).put(r.admin_contract_path(mine), params: { contract: valid_update[:contract].merge(title: '') })
  h.check_status('invalid update re-renders form', res, [200, 422])

  # --- accept -------------------------------------------------------------
  puts '-- accept'
  %i[secondary financial office_king].zip([secondary, financial, office_king]).each do |label, who|
    contract = make_contract.call
    h.clear_enqueued_jobs!
    res = c.(label.to_s, who).put(r.accept_admin_contract_path(contract))
    h.check_status("#{label} accepts new contract", res, 302)
    contract.reload
    h.check("#{label}: state accepted, checker set", [contract.state, contract.checker_id], ['accepted', who.id])
    h.check("#{label}: creator notified", NotificationCenter::NotificationRecord.where(notifiable_id: contract.id, action: 'accepted_contract', recipient_id: member.id).count, 1)
    h.check("#{label}: state-change mail enqueued", h.enqueued_jobs.size, 1..)
  end

  untyped = make_contract.call(typed: false)
  res = c.('office_king', office_king).put(r.accept_admin_contract_path(untyped))
  h.check_status('accept without types redirects to edit', res, 302)
  h.check('accept without types redirects to edit page', res.location.to_s, %r{/admin/contracts/#{untyped.id}/edit})
  h.check('contract without types stays new', untyped.reload.state, 'new')

  h.check_denied('member cannot accept', c.('member', member).put(r.accept_admin_contract_path(make_contract.call)))
  victim = make_contract.call
  anon.put(r.accept_admin_contract_path(victim))
  h.check('anonymous accept leaves state new', victim.reload.state, 'new')

  already = make_contract.call(state: 'accepted', checker_id: office_king.id)
  res = c.('office_king', office_king).put(r.accept_admin_contract_path(already))
  h.check_status('accepting already accepted contract does not 500', res, 302)

  # --- prepayment ---------------------------------------------------------
  puts '-- prepayment'
  accepted = make_contract.call(state: 'accepted', checker_id: office_king.id)
  res = c.('financial', financial).put(r.prepayment_admin_contract_path(accepted))
  h.check_status('financial moves accepted -> preclosed', res, 302)
  accepted.reload
  h.check('preclosed with acceptor and date', [accepted.state, accepted.acceptor_id, accepted.preclosed_date.present?], ['preclosed', financial.id, true])

  accepted2 = make_contract.call(state: 'accepted', checker_id: office_king.id)
  c.('secondary', secondary).put(r.prepayment_admin_contract_path(accepted2))
  h.known_gap('G37', 'secondary_management cannot prepay (class-level authorize! passes through its manage grant)', accepted2.reload.state, 'accepted')
  h.check_denied('member cannot prepay', c.('member', member).put(r.prepayment_admin_contract_path(accepted2)))

  fresh = make_contract.call
  res = c.('financial', financial).put(r.prepayment_admin_contract_path(fresh))
  h.check_status('prepayment of a new contract does not 500', res, 302)
  h.check('new contract was not moved to preclosed', fresh.reload.state, 'new')

  # --- finish -------------------------------------------------------------
  puts '-- finish'
  closable = { substantive_type: 'salary', area_type: 'it', financial_type: 'internal' }
  preclosed = make_contract.call(state: 'preclosed', checker_id: office_king.id, acceptor_id: financial.id, **closable)
  res = c.('office_king', office_king).put(r.finish_admin_contract_path(preclosed))
  h.check_status('office_king finishes preclosed contract', res, 302)
  preclosed.reload
  h.check('closed with closer', [preclosed.state, preclosed.closer_id], ['closed', office_king.id])

  preclosed2 = make_contract.call(state: 'preclosed', checker_id: office_king.id, acceptor_id: financial.id, **closable)
  c.('financial', financial).put(r.finish_admin_contract_path(preclosed2))
  h.known_gap('G37', 'financial_management cannot finish (class-level authorize! passes through its manage grant)', preclosed2.reload.state, 'preclosed')

  not_ready = make_contract.call(state: 'accepted', checker_id: office_king.id, **closable)
  c.('office_king', office_king).put(r.finish_admin_contract_path(not_ready))
  not_ready.reload
  h.check('finish on non-preclosed contract does not record a closer', [not_ready.state, not_ready.closer_id], ['accepted', nil])

  incomplete = make_contract.call(state: 'preclosed', checker_id: office_king.id, acceptor_id: financial.id)
  res = c.('office_king', office_king).put(r.finish_admin_contract_path(incomplete))
  h.check('finish without expense fields redirects to edit', res.location.to_s, %r{/edit})
  h.check('contract stays preclosed', incomplete.reload.state, 'preclosed')

  # --- destroy ------------------------------------------------------------
  puts '-- destroy'
  doomed = make_contract.call
  h.check_denied('member cannot destroy', c.('member', member).delete(r.admin_contract_path(doomed)))
  h.check_denied('financial cannot destroy', c.('financial', financial).delete(r.admin_contract_path(doomed)))
  h.check_denied('anonymous cannot destroy', anon.delete(r.admin_contract_path(doomed)))
  h.check('contract survived denied deletes', Settlement::ContractRecord.exists?(doomed.id), true)
  h.check_status('office_king destroys contract', c.('office_king', office_king).delete(r.admin_contract_path(doomed)), 302)
  h.check('contract is gone', Settlement::ContractRecord.exists?(doomed.id), false)

  # --- download_attachment ------------------------------------------------
  puts '-- download_attachment'
  probe = make_contract.call
  path = r.download_attachment_admin_contract_path(probe, url: '/etc/hostname', filename: 'probe.txt')
  res = anon.get(path)
  h.check_denied('anonymous cannot download arbitrary server file', res)
  res = c.('other', other).get(path)
  h.check_denied('unrelated user cannot download arbitrary server file', res)
end
