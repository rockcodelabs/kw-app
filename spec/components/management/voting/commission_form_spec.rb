# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Management::Voting::CommissionForm do
  subject(:form) { described_class.new }

  let(:params) { { approval: '1', owner_id: '1', authorized_id: '2' } }

  it 'accepts valid params and coerces types' do
    expect(form.call(params).to_h).to eq(approval: true, owner_id: 1, authorized_id: 2)
  end

  %i[approval owner_id authorized_id].each do |key|
    it "requires #{key}" do
      expect(form.call(params.merge(key => '')).errors.to_h).to have_key(key)
    end
  end
end
