# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Management::CreateProject do
  subject(:service) { described_class.new(Management::ProjectForm) }

  def params(hash)
    ActionController::Parameters.new(hash)
  end

  it 'creates the project' do
    expect { expect(service.call(raw_inputs: params(name: 'Nowy', description: 'Opis'))).to eq(Dry::Monads::Success(:success)) }
      .to change(Management::ProjectRecord, :count).by(1)

    expect(Management::ProjectRecord.last).to have_attributes(name: 'Nowy', description: 'Opis')
  end

  it 'returns Polish errors and creates nothing when the name is blank' do
    result = nil

    expect { result = service.call(raw_inputs: params(name: '')) }.not_to change(Management::ProjectRecord, :count)

    expect(result).to be_failure
    expect(result.failure[:name]).to eq(['musi być wypełnione'])
  end
end
