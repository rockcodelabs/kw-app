# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Management::Voting::CasesController', type: :request do
  let(:voter) { create(:user, :with_membership, :with_profile, roles: ['voting']) }

  def case_params(overrides = {})
    { case: { name: 'Uchwała 1', creator_id: voter.id, voting_type: 'document', meeting_type: 'circle' }.merge(overrides) }
  end

  before { sign_in voter }

  describe 'POST create' do
    it 'creates a case' do
      expect { post cases_path, params: case_params }
        .to change(Management::Voting::CaseRecord, :count).by(1)

      expect(response).to redirect_to(walne_cases_path)
      expect(Management::Voting::CaseRecord.last).to have_attributes(name: 'Uchwała 1', creator_id: voter.id)
    end

    it 're-renders the form with a message when the name is missing' do
      expect { post cases_path, params: case_params(name: '') }
        .not_to change(Management::Voting::CaseRecord, :count)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('musi być wypełnione')
    end
  end

  describe 'PUT update' do
    let!(:case_record) do
      Management::Voting::CaseRecord.create!(name: 'Stara', creator_id: voter.id, voting_type: 'document', meeting_type: 'circle')
    end

    it 'updates the case' do
      put case_path(case_record.id), params: case_params(name: 'Nowa')

      expect(response).to redirect_to(case_path(case_record.id))
      expect(case_record.reload.name).to eq('Nowa')
    end

    it 're-renders the form when the name is blank' do
      put case_path(case_record.id), params: case_params(name: '')

      expect(response).to have_http_status(:ok)
      expect(case_record.reload.name).to eq('Stara')
    end
  end
end
