# frozen_string_literal: true

require 'rails_helper'

# Post-deploy critical flow: the contract state machine
# new -> accepted -> preclosed -> closed (accept / prepayment / finish).
RSpec.describe 'Settlement::Admin::ContractsController workflow', type: :request do
  let(:creator) { create(:user, :with_membership, :with_profile) }
  let(:contractor) { Settlement::ContractorRecord.create!(name: 'ACME') }
  let(:office_king) { create(:user, :with_membership, :with_profile, roles: ['office_king']) }
  let(:financial) { create(:user, :with_membership, :with_profile, roles: ['financial_management']) }
  let(:outsider) { create(:user, :with_membership, :with_profile) }

  let(:classification) { { activity_type: :courses, group_type: :kw, event_type: :not_event } }
  let(:finish_classification) { { substantive_type: :materials, area_type: :it } }

  def build_contract(**attrs)
    Settlement::ContractRecord.create!(
      {
        title: 'Workflow contract', creator_id: creator.id, contractor_id: contractor.id,
        document_number: 'FV/9', document_date: Date.current, cost: 100.0, currency_type: :pln,
        document_type: :bill, payout_type: :to_contractor,
        period_date: Date.new(Date.current.year, 1, 1), internal_number: 9
      }.merge(attrs)
    )
  end

  before { ActiveJob::Base.queue_adapter = :test }

  describe 'PUT accept' do
    let(:contract) { build_contract(**classification).tap { |c| c.update!(user_ids: [creator.id]) } }

    it 'moves a new contract to accepted, records the checker, notifies the contract users and enqueues the mail' do
      sign_in office_king

      expect { put accept_admin_contract_path(contract) }
        .to have_enqueued_mail(Settlement::ContractMailer, :state_changed)
        .and change { NotificationCenter::NotificationRecord.where(recipient_id: creator.id, action: 'accepted_contract').count }.by(1)

      expect(contract.reload.state).to eq('accepted')
      expect(contract.checker_id).to eq(office_king.id)
      expect(flash[:notice]).to eq('Sprawdzono!')
    end

    it 'refuses and keeps the state when Sekcja, Aktywność or Impreza are missing' do
      sign_in office_king
      bare = build_contract(internal_number: 10, document_number: 'FV/10')

      put accept_admin_contract_path(bare)

      expect(bare.reload.state).to eq('new')
      expect(flash[:alert]).to include('Wypełnij pola')
    end

    it 'denies a user without the accept ability' do
      sign_in outsider

      put accept_admin_contract_path(contract)

      expect(contract.reload.state).to eq('new')
    end

    it 'does not touch the contract for anonymous users' do
      put accept_admin_contract_path(contract)

      expect(contract.reload.state).to eq('new')
    end

    it 'handles accepting an already accepted contract (double click) without an error or a changed checker' do
      sign_in office_king
      contract.accept!
      contract.update!(checker_id: financial.id)

      put accept_admin_contract_path(contract)

      expect(response).to have_http_status(:redirect)
      expect(flash[:alert]).to be_present
      expect(contract.reload.state).to eq('accepted')
      expect(contract.checker_id).to eq(financial.id)
    end
  end

  describe 'PUT prepayment' do
    let(:contract) do
      build_contract(**classification).tap(&:accept!)
    end

    it 'moves an accepted contract to preclosed and stamps the acceptor' do
      sign_in financial

      expect { put prepayment_admin_contract_path(contract) }
        .to have_enqueued_mail(Settlement::ContractMailer, :state_changed)

      contract.reload
      expect(contract.state).to eq('preclosed')
      expect(contract.acceptor_id).to eq(financial.id)
      expect(contract.preclosed_date).to be_present
    end

    it 'denies a user without the prepayment ability' do
      sign_in outsider

      put prepayment_admin_contract_path(contract)

      expect(contract.reload.state).to eq('accepted')
    end

    it 'handles prepayment of a contract that is not accepted without an error or stamps' do
      sign_in financial
      fresh = build_contract(**classification, internal_number: 12, document_number: 'FV/12')

      put prepayment_admin_contract_path(fresh)

      expect(response).to have_http_status(:redirect)
      expect(flash[:alert]).to be_present
      fresh.reload
      expect(fresh.state).to eq('new')
      expect(fresh.acceptor_id).to be_nil
    end
  end

  describe 'PUT finish' do
    let(:contract) do
      build_contract(**classification, **finish_classification).tap do |c|
        c.accept!
        c.prepayment!
      end
    end

    it 'closes a preclosed contract and stamps the closer' do
      sign_in office_king

      expect { put finish_admin_contract_path(contract) }
        .to have_enqueued_mail(Settlement::ContractMailer, :state_changed)

      contract.reload
      expect(contract.state).to eq('closed')
      expect(contract.closer_id).to eq(office_king.id)
      expect(flash[:notice]).to eq('Rozliczono!')
    end

    it 'refuses and keeps the state when the expense fields are missing' do
      sign_in office_king
      incomplete = build_contract(**classification, internal_number: 11, document_number: 'FV/11')
      incomplete.accept!
      incomplete.prepayment!

      put finish_admin_contract_path(incomplete)

      expect(incomplete.reload.state).to eq('preclosed')
      expect(flash[:alert]).to include('Wypełnij pola')
    end

    it 'does not record a closer when the contract is not preclosed' do
      sign_in office_king
      accepted = build_contract(**classification, **finish_classification, internal_number: 13, document_number: 'FV/13')
      accepted.accept!

      put finish_admin_contract_path(accepted)

      accepted.reload
      expect(accepted.state).to eq('accepted')
      expect(accepted.closer_id).to be_nil
    end

    it 'denies a user without the finish ability' do
      sign_in outsider

      put finish_admin_contract_path(contract)

      expect(contract.reload.state).to eq('preclosed')
    end
  end
end
