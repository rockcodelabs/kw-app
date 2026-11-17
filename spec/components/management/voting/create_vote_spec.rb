# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Management::Voting::CreateVote do
  subject(:service) { described_class.new(Management::Voting::VoteForm) }

  let(:member) { create(:user, :with_membership, :with_profile) }
  let(:other) { create(:user, :with_membership, :with_profile) }
  let!(:case_record) { Management::Voting::CaseRecord.create!(name: 'Uchwała', creator_id: member.id, voting_type: 'document', state: 'voting') }
  let(:inputs) do
    { case_id: case_record.id.to_s, user_id: member.id.to_s, authorized_id: member.id.to_s, commission: 'false', decision: 'approved' }
  end

  def call(current_user_id: member.id, **overrides)
    service.call(raw_inputs: ActionController::Parameters.new(inputs.merge(overrides)), current_user_id: current_user_id)
  end

  it 'records the vote and returns the case id' do
    result = nil

    expect { result = call }.to change(Management::Voting::VoteRecord, :count).by(1)

    expect(result).to eq(Dry::Monads::Success(case_record.id))
  end

  it 'fails with the case id when the form is invalid' do
    result = call(user_id: '')

    expect(result).to eq(Dry::Monads::Failure(case_record.id.to_s))
  end

  it 'fails when the case is not in the voting state' do
    case_record.update!(state: 'finished')

    expect { expect(call).to be_failure }.not_to change(Management::Voting::VoteRecord, :count)
  end

  it 'fails when voting for someone without a commission' do
    expect { expect(call(user_id: other.id.to_s)).to be_failure }.not_to change(Management::Voting::VoteRecord, :count)
  end

  it 'allows voting on behalf of an owner who granted a commission' do
    Management::Voting::CommissionRecord.create!(owner_id: other.id, authorized_id: member.id, approval: true)

    expect { expect(call(user_id: other.id.to_s, commission: 'true')).to be_success }
      .to change(Management::Voting::VoteRecord, :count).by(1)
  end
end
