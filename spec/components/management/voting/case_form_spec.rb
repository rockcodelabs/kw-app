# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Management::Voting::CaseForm do
  subject(:form) { described_class.new }

  let(:params) { { name: 'Uchwała', creator_id: '5', voting_type: 'document' } }

  it 'accepts the required params and coerces the creator id' do
    result = form.call(params)

    expect(result).to be_success
    expect(result[:creator_id]).to eq(5)
  end

  %i[name creator_id voting_type].each do |key|
    it "requires #{key}" do
      expect(form.call(params.merge(key => '')).errors.to_h).to have_key(key)
    end
  end

  it 'coerces boolean flags' do
    expect(form.call(params.merge(hide_votes: '1', public: 'false')).to_h).to include(hide_votes: true, public: false)
  end

  it 'rejects an invalid acceptance date' do
    expect(form.call(params.merge(acceptance_date: 'nie data')).errors.to_h).to have_key(:acceptance_date)
  end
end
