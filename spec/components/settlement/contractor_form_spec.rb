# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Settlement::ContractorForm do
  subject(:form) { described_class.new }

  let(:params) { { name: 'Firma', nip: '1234567890', reason_type: 'both', profession_type: 'no_profession' } }

  it 'accepts valid params' do
    expect(form.call(params)).to be_success
  end

  %i[name reason_type profession_type].each do |key|
    it "requires #{key}" do
      expect(form.call(params.merge(key => '')).errors.to_h).to have_key(key)
    end
  end

  it 'allows a blank nip' do
    expect(form.call(params.merge(nip: ''))).to be_success
  end

  it 'rejects an already used nip' do
    Settlement::ContractorRecord.create!(params.merge(email: 'a@example.com'))

    expect(form.call(params).errors.to_h).to have_key(:nip)
  end
end
