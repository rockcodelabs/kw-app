# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Management::Voting::UpdateCase do
  subject(:service) { described_class.new(Management::Voting::CaseForm) }

  let(:creator) { create(:user, :with_membership, :with_profile) }
  let!(:case_record) { Management::Voting::CaseRecord.create!(name: 'Stara', creator_id: creator.id, voting_type: 'document') }
  let(:inputs) { { name: 'Nowa', creator_id: creator.id.to_s, voting_type: 'document' } }

  def call(overrides = {})
    service.call(id: case_record.id, raw_inputs: ActionController::Parameters.new(inputs.merge(overrides)))
  end

  it 'updates the case and returns its id' do
    expect(call).to eq(Dry::Monads::Success(case_record.id))
    expect(case_record.reload.name).to eq('Nowa')
  end

  it 'returns Polish errors and keeps the case when invalid' do
    result = call(name: '')

    expect(result.failure[:name]).to eq(['musi być wypełnione'])
    expect(case_record.reload.name).to eq('Stara')
  end

  it 'raises for an unknown case' do
    expect { service.call(id: 0, raw_inputs: ActionController::Parameters.new(inputs)) }.to raise_error(ActiveRecord::RecordNotFound)
  end
end
