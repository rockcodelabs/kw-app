# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Management::Voting::VoteForm do
  subject(:form) { described_class.new }

  let(:params) { { case_id: '1', user_id: '2', authorized_id: '2', commission: 'false', decision: 'approved' } }

  it 'accepts valid params and coerces types' do
    result = form.call(params)

    expect(result).to be_success
    expect(result.to_h).to include(case_id: 1, user_id: 2, authorized_id: 2, commission: false)
  end

  %i[case_id user_id authorized_id].each do |key|
    it "requires #{key}" do
      expect(form.call(params.merge(key => '')).errors.to_h).to have_key(key)
    end
  end

  it 'requires the commission flag' do
    expect(form.call(params.except(:commission)).errors.to_h).to have_key(:commission)
  end

  it 'does not require a decision' do
    expect(form.call(params.except(:decision))).to be_success
  end
end
