# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Settlement::CreateContractor do
  subject(:service) { described_class.new(Settlement::Repository.new, Settlement::ContractorForm) }

  let(:params) do
    ActionController::Parameters.new(name: 'Firma', nip: '1234567890', reason_type: 'both', profession_type: 'no_profession')
  end

  it 'creates the contractor and returns it' do
    result = nil

    expect { result = service.call(raw_inputs: params) }.to change(Settlement::ContractorRecord, :count).by(1)

    expect(result).to be_success
    expect(result.value!).to have_attributes(name: 'Firma', nip: '1234567890')
  end

  it 'returns full Polish errors when invalid' do
    result = service.call(raw_inputs: ActionController::Parameters.new(name: '', reason_type: 'both', profession_type: 'no_profession'))

    expect(result).to be_failure
    expect(result.failure).to have_key(:name)
  end

  it 'fails for a duplicated nip' do
    service.call(raw_inputs: params)

    expect(service.call(raw_inputs: params)).to be_failure
  end
end
