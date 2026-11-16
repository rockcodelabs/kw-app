# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Settlement::Admin::ContractsController', type: :request do
  let(:creator) { create(:user, :with_membership, :with_profile) }
  let(:contractor) { Settlement::ContractorRecord.create!(name: 'ACME') }
  let(:contract) do
    Settlement::ContractRecord.create!(
      title: 'Test contract', creator_id: creator.id, contractor_id: contractor.id,
      document_number: 'FV/1', document_date: Date.current, cost: 100.0, currency_type: :pln,
      document_type: :bill, payout_type: :to_contractor, period_date: Date.new(Date.current.year, 1, 1),
      internal_number: 1
    )
  end
  let(:office_king) { create(:user, :with_membership, :with_profile, roles: ['office_king']) }
  let(:outsider) { create(:user, :with_membership, :with_profile) }

  let(:create_params) do
    {
      contract: {
        title: 'Nowe rozliczenie', contractor_id: contractor.id.to_s, document_number: 'FV/2',
        document_date: Date.current.to_s, currency_type: 'pln', cost: '120.50', description: 'opis',
        document_type: 'charities', payout_type: 'to_contractor', group_type: 'kw',
        user_ids: [creator.id.to_s]
      }
    }
  end

  let(:update_params) do
    {
      contract: {
        title: 'Zmieniony tytul', cost: '200', document_type: 'bill', payout_type: 'to_contractor',
        currency_type: 'pln', document_date: Date.current.to_s, document_number: 'FV/1', description: 'x',
        user_ids: [creator.id.to_s]
      }
    }
  end

  before { ActiveJob::Base.queue_adapter = :test }

  describe 'GET download_attachment' do
    let(:attachment_path) { Rails.root.join('tmp', 'contract_attachment_spec.txt') }

    before { File.write(attachment_path, 'secret contents') }
    after { FileUtils.rm_f(attachment_path) }

    def attach_file!
      stored = CarrierWave::SanitizedFile.new(attachment_path.to_s)
      attachment = instance_double(Settlement::AttachmentUploader, url: '/uploads/contract_attachment_spec.txt', file: stored)
      allow_any_instance_of(Settlement::ContractRecord).to receive(:attachments).and_return([attachment])
      attachment
    end

    it 'does not serve arbitrary server files, even to a privileged user' do
      sign_in office_king

      get download_attachment_admin_contract_path(contract), params: { url: '/etc/hostname', filename: 'x' }

      expect(response).not_to have_http_status(:ok)
      expect(response.headers['Content-Disposition'].to_s).not_to include('attachment')
    end

    it 'denies users who cannot read the contract' do
      attachment = attach_file!
      sign_in outsider

      get download_attachment_admin_contract_path(contract), params: { url: attachment.url, filename: 'a.txt' }

      expect(response).not_to have_http_status(:ok)
    end

    it 'denies anonymous users' do
      attachment = attach_file!

      get download_attachment_admin_contract_path(contract), params: { url: attachment.url, filename: 'a.txt' }

      expect(response).not_to have_http_status(:ok)
    end

    it 'serves an attachment of the contract to a user who can read it' do
      attachment = attach_file!
      sign_in creator

      get download_attachment_admin_contract_path(contract), params: { url: attachment.url, filename: 'a.txt' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq('secret contents')
    end
  end

  describe 'POST create' do
    it 'creates a contract and redirects to the list' do
      sign_in creator

      expect { post admin_contracts_path, params: create_params }.to change(Settlement::ContractRecord, :count).by(1)

      expect(response).to redirect_to(admin_contracts_path)
      expect(Settlement::ContractRecord.last).to have_attributes(creator_id: creator.id, title: 'Nowe rozliczenie')
    end

    it 're-renders the form with errors when input is invalid' do
      sign_in creator
      create_params[:contract][:title] = ''

      expect { post admin_contracts_path, params: create_params }.not_to change(Settlement::ContractRecord, :count)

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'PATCH update' do
    it 'updates the contract for its creator' do
      sign_in creator

      patch admin_contract_path(contract), params: update_params

      expect(response).to redirect_to(edit_admin_contract_path(contract.id))
      expect(contract.reload.title).to eq('Zmieniony tytul')
    end

    it 're-renders the form with errors when input is invalid' do
      sign_in creator
      update_params[:contract][:title] = ''

      patch admin_contract_path(contract), params: update_params

      expect(response).to have_http_status(:ok)
      expect(contract.reload.title).to eq('Test contract')
    end

    it 'denies users who cannot update the contract' do
      sign_in outsider

      patch admin_contract_path(contract), params: update_params

      expect(response).to redirect_to(root_path)
      expect(contract.reload.title).to eq('Test contract')
    end

    it 'denies anonymous users without raising' do
      patch admin_contract_path(contract), params: update_params

      expect(response).to have_http_status(:redirect)
      expect(contract.reload.title).to eq('Test contract')
    end

    it 'shows validation messages in Polish' do
      sign_in creator
      update_params[:contract][:title] = ''

      patch admin_contract_path(contract), params: update_params

      expect(response.body).to include('brakuje').or include('musi być wype')
    end

    context 'when the user is an office king' do
      before do
        sign_in office_king
        update_params[:contract].merge!('period_date(1i)': Date.current.year.to_s, internal_number: '5')
      end

      it 'updates the contract' do
        patch admin_contract_path(contract), params: update_params

        expect(response).to redirect_to(edit_admin_contract_path(contract.id))
        expect(contract.reload).to have_attributes(title: 'Zmieniony tytul', internal_number: 5)
      end

      it 'rejects an internal number already used in that year' do
        other = contract.dup.tap { |c| c.update!(internal_number: 5) }

        patch admin_contract_path(contract), params: update_params

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('taki numer już istnieje')
        expect(contract.reload.internal_number).to eq(1)
        expect(other.reload.internal_number).to eq(5)
      end
    end

    it 'does not let a user without the ability trigger a workflow step through verify' do
      sign_in creator
      update_params[:verify] = 'prepayment'

      patch admin_contract_path(contract), params: update_params

      expect(response).to redirect_to(root_path)
      expect(contract.reload.state).to eq('new')
    end
  end

  describe 'GET history' do
    it 'denies plain members' do
      sign_in outsider

      get history_admin_contracts_path

      expect(response).to redirect_to(root_path)
    end

    it 'denies anonymous users' do
      get history_admin_contracts_path

      expect(response).to redirect_to(root_path)
    end

    it 'is available to users who can read versions' do
      sign_in office_king

      get history_admin_contracts_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET analiza' do
    it 'denies plain members' do
      sign_in outsider

      get "/rozliczenia/analiza/#{Date.current.year}"

      expect(response).to redirect_to(root_path)
    end

    it 'denies anonymous users' do
      get "/rozliczenia/analiza/#{Date.current.year}"

      expect(response).to redirect_to(root_path)
    end

    it 'is available to users who can analyse contracts' do
      sign_in office_king

      get "/rozliczenia/analiza/#{Date.current.year}"

      expect(response).to have_http_status(:ok)
    end
  end
end
