# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Settlement::Admin::ContractorsController', type: :request do
  let(:member) { create(:user, :with_membership, :with_profile) }
  let(:manager) { create(:user, :with_membership, :with_profile, roles: ['office']) }

  let(:params) do
    { contractor: { name: 'Nowy kontrahent', nip: '1234567890', email: 'a@example.com', reason_type: 'both', profession_type: 'no_profession' } }
  end

  describe 'POST create' do
    it 'creates a contractor and redirects to the list' do
      sign_in member

      expect { post admin_contractors_path, params: params }.to change(Settlement::ContractorRecord, :count).by(1)

      expect(response).to redirect_to(admin_contractors_path)
      expect(Settlement::ContractorRecord.last).to have_attributes(name: 'Nowy kontrahent', nip: '1234567890')
    end

    it 'redirects back to the sponsorship request form when asked to' do
      sign_in member
      params[:contractor][:back_url] = 'new_sponsorship_request'

      post admin_contractors_path, params: params

      expect(response).to redirect_to(new_sponsorship_request_path)
    end

    it 're-renders the form when the quick-add flag is set' do
      sign_in member

      expect { post admin_contractors_path, params: params.merge(quick: true) }.to change(Settlement::ContractorRecord, :count).by(1)

      expect(response).to have_http_status(:ok)
    end

    it 're-renders the form with errors when the name is missing' do
      sign_in member
      params[:contractor][:name] = ''

      expect { post admin_contractors_path, params: params }.not_to change(Settlement::ContractorRecord, :count)

      expect(response).to have_http_status(:ok)
    end

    it 'rejects a NIP that already exists' do
      Settlement::ContractorRecord.create!(name: 'Istniejacy', nip: '1234567890')
      sign_in member

      expect { post admin_contractors_path, params: params }.not_to change(Settlement::ContractorRecord, :count)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('nip juz istnieje')
    end

    it 'denies anonymous users' do
      expect { post admin_contractors_path, params: params }.not_to change(Settlement::ContractorRecord, :count)

      expect(response).to have_http_status(:redirect)
    end
  end

  describe 'PATCH update' do
    let!(:contractor) { Settlement::ContractorRecord.create!(name: 'Stara nazwa') }

    it 'updates the contractor for a manager' do
      sign_in manager

      patch admin_contractor_path(contractor), params: { contractor: { name: 'Nowa nazwa' } }

      expect(response).to redirect_to(admin_contractor_path(contractor.id))
      expect(contractor.reload.name).to eq('Nowa nazwa')
    end

    it 're-renders the form when the update is invalid' do
      sign_in manager

      patch admin_contractor_path(contractor), params: { contractor: { name: '' } }

      expect(response).to have_http_status(:ok)
      expect(contractor.reload.name).to eq('Stara nazwa')
    end

    it 'denies plain members' do
      sign_in member

      patch admin_contractor_path(contractor), params: { contractor: { name: 'Nowa nazwa' } }

      expect(contractor.reload.name).to eq('Stara nazwa')
    end
  end
end
