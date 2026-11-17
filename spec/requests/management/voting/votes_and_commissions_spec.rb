# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Management voting votes and commissions', type: :request do
  let(:member) { create(:user, :with_membership, :with_profile) }
  let(:other) { create(:user, :with_membership, :with_profile) }
  let!(:case_record) do
    Management::Voting::CaseRecord.create!(name: 'Uchwała', creator_id: member.id, voting_type: 'document', state: 'voting')
  end

  before do
    allow_any_instance_of(Db::User).to receive(:active_and_regular?).and_return(true)
    sign_in member
  end

  describe 'POST votes#create' do
    let(:vote_params) do
      { vote: { case_id: case_record.id, user_id: member.id, authorized_id: member.id, commission: 'false', decision: 'approved' } }
    end

    it 'records the vote' do
      expect { post votes_path(case_record.id), params: vote_params }
        .to change(Management::Voting::VoteRecord, :count).by(1)

      expect(response).to redirect_to(case_path(case_record.id))
      expect(flash[:notice]).to eq('Zagłosowano')
    end

    it 'rejects the vote when the case is no longer voting' do
      case_record.update!(state: 'finished')

      expect { post votes_path(case_record.id), params: vote_params }
        .not_to change(Management::Voting::VoteRecord, :count)

      expect(response).to redirect_to(case_path(case_record.id))
      expect(flash[:alert]).to include('czas na oddanie głosu już minął')
    end

    it 'rejects the vote when the form is invalid' do
      vote_params[:vote].delete(:user_id)

      expect { post votes_path(case_record.id), params: vote_params }
        .not_to change(Management::Voting::VoteRecord, :count)

      expect(flash[:alert]).to be_present
    end

    it 'rejects a vote cast for someone without a commission' do
      vote_params[:vote][:user_id] = other.id

      expect { post votes_path(case_record.id), params: vote_params }
        .not_to change(Management::Voting::VoteRecord, :count)
    end
  end

  describe 'POST commissions#create' do
    it 'creates a commission' do
      expect { post commissions_path, params: { commission: { owner_id: member.id, authorized_id: other.id, approval: '1' } } }
        .to change(Management::Voting::CommissionRecord, :count).by(1)

      expect(response).to redirect_to('/glosowania/pelnomocnictwo')
    end

    it 're-renders the form when the owner and the authorized user are the same' do
      expect { post commissions_path, params: { commission: { owner_id: member.id, authorized_id: member.id, approval: '1' } } }
        .not_to change(Management::Voting::CommissionRecord, :count)

      expect(response).to have_http_status(:ok)
    end
  end
end
