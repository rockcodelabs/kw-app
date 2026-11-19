# frozen_string_literal: true

require 'rails_helper'

# Post-deploy critical flow: browsing contracts (list per role, archive, show, forms) and deleting them.
RSpec.describe 'Settlement::Admin::ContractsController pages', type: :request do
  let(:creator) { create(:user, :with_membership, :with_profile) }
  let(:other_member) { create(:user, :with_membership, :with_profile) }
  let(:contractor) { Settlement::ContractorRecord.create!(name: 'ACME') }
  let(:office_king) { create(:user, :with_membership, :with_profile, roles: ['office_king']) }
  let(:financial) { create(:user, :with_membership, :with_profile, roles: ['financial_management']) }
  let(:secondary) { create(:user, :with_membership, :with_profile, roles: ['secondary_management']) }

  def build_contract(number, **attrs)
    Settlement::ContractRecord.create!(
      {
        title: "Rozliczenie #{number}", creator_id: creator.id, contractor_id: contractor.id,
        document_number: "FV/#{number}", document_date: Date.current, cost: 100.0, currency_type: :pln,
        document_type: :bill, payout_type: :to_contractor,
        period_date: Date.new(Date.current.year, 1, 1), internal_number: number
      }.merge(attrs)
    )
  end

  let!(:open_contract) { build_contract(1) }
  let!(:closed_contract) { build_contract(2).tap { |c| c.update_columns(state: 'closed') } }
  let!(:foreign_contract) { build_contract(3, creator_id: other_member.id) }

  before { ActiveJob::Base.queue_adapter = :test }

  describe 'GET /rozliczenia (index)' do
    it 'lists open contracts and hides closed ones by default, for an office king' do
      sign_in office_king

      get admin_contracts_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Rozliczenie 1', 'Rozliczenie 3')
      expect(response.body).not_to include('Rozliczenie 2')
    end

    it 'shows a member only the contracts they created' do
      sign_in creator

      get admin_contracts_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Rozliczenie 1')
      expect(response.body).not_to include('Rozliczenie 3')
    end

    it 'shows a member the contracts they are listed on' do
      foreign_contract.update!(user_ids: [creator.id])
      sign_in creator

      get admin_contracts_path

      expect(response.body).to include('Rozliczenie 3')
    end

    it 'includes closed contracts when a filter is given' do
      sign_in office_king

      get admin_contracts_path, params: { q: { title_cont: 'Rozliczenie' } }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Rozliczenie 1', 'Rozliczenie 2', 'Rozliczenie 3')
    end

    it 'accepts a custom_state sort in both directions' do
      sign_in office_king

      %w[custom_state\ asc custom_state\ desc].each do |sort|
        get admin_contracts_path, params: { q: { s: sort } }

        expect(response).to have_http_status(:ok)
      end
    end

    it 'exports the list to xlsx' do
      sign_in office_king

      get admin_contracts_path(format: :xlsx)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to include('spreadsheet')
      expect(response.headers['Content-Disposition']).to include('rozliczenia_')
    end

    it 'redirects anonymous users' do
      get admin_contracts_path

      expect(response).to have_http_status(:redirect)
    end
  end

  describe 'GET archive' do
    it 'lists contracts of every state for an office king' do
      sign_in office_king

      get archive_admin_contracts_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Rozliczenie 1', 'Rozliczenie 2')
    end

    it 'offers an export link that points at the working index export' do
      sign_in office_king

      get archive_admin_contracts_path

      expect(response.body).to include('Export')
      expect(response.body).to match(%r{href="/admin/contracts\?[^"]*format=xlsx"})
    end
  end

  describe 'GET show' do
    it 'renders for the creator' do
      sign_in creator

      get admin_contract_path(open_contract)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Rozliczenie 1')
    end

    it 'renders for a user listed on the contract' do
      open_contract.update!(user_ids: [other_member.id])
      sign_in other_member

      get admin_contract_path(open_contract)

      expect(response).to have_http_status(:ok)
    end

    it 'denies a member who has nothing to do with the contract' do
      sign_in other_member

      get admin_contract_path(open_contract)

      expect(response).to have_http_status(:redirect)
      expect(response.body).not_to include('Rozliczenie 1')
    end

    it 'renders for every state, for an office king' do
      sign_in office_king

      %w[new accepted preclosed closed].each do |state|
        open_contract.update_columns(state: state)

        get admin_contract_path(open_contract)

        expect(response).to have_http_status(:ok), "state #{state} did not render"
      end
    end
  end

  describe 'GET new / edit' do
    it 'renders the new form for a member' do
      sign_in creator

      get new_admin_contract_path

      expect(response).to have_http_status(:ok)
    end

    it 'renders the edit form for the creator' do
      sign_in creator

      get edit_admin_contract_path(open_contract)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Rozliczenie 1')
    end

    it 'does not render the edit form for an unrelated member' do
      sign_in other_member

      get edit_admin_contract_path(open_contract)

      expect(response).to have_http_status(:redirect)
    end

    it 'renders the edit form for an office king in every state' do
      sign_in office_king

      %w[new accepted preclosed closed].each do |state|
        open_contract.update_columns(state: state)

        get edit_admin_contract_path(open_contract)

        expect(response).to have_http_status(:ok), "state #{state} did not render"
      end
    end
  end

  describe 'DELETE destroy' do
    it 'lets an office king delete a contract' do
      sign_in office_king

      expect { delete admin_contract_path(open_contract) }.to change(Settlement::ContractRecord, :count).by(-1)
      expect(flash[:notice]).to eq('Usunięto!')
    end

    it 'does not let financial or secondary management delete a contract' do
      [financial, secondary].each do |user|
        sign_in user

        expect { delete admin_contract_path(open_contract) }.not_to change(Settlement::ContractRecord, :count)
      end
    end

    it 'does not let the creator or an anonymous user delete a contract' do
      sign_in creator
      expect { delete admin_contract_path(open_contract) }.not_to change(Settlement::ContractRecord, :count)
      sign_out creator

      expect { delete admin_contract_path(open_contract) }.not_to change(Settlement::ContractRecord, :count)
    end
  end
end
