# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Management::UpdateProject do
  subject(:service) { described_class.new(Management::ProjectForm) }

  let!(:project) { Management::ProjectRecord.create!(name: 'Stary', state: 'draft') }

  def params(hash)
    ActionController::Parameters.new(hash)
  end

  it 'updates the project and returns it' do
    result = service.call(id: project.id, raw_inputs: params(name: 'Nowy', state: 'in_progress'))

    expect(result).to be_success
    expect(result.value!).to eq(project)
    expect(project.reload).to have_attributes(name: 'Nowy', state: 'in_progress')
  end

  it 'returns Polish errors and keeps the project when invalid' do
    result = service.call(id: project.id, raw_inputs: params(name: ''))

    expect(result.failure[:name]).to eq(['musi być wypełnione'])
    expect(project.reload.name).to eq('Stary')
  end

  it 'returns a base error for an unknown project' do
    result = service.call(id: 0, raw_inputs: params(name: 'X'))

    expect(result).to eq(Dry::Monads::Failure(base: ['projekt nie został znaleziony']))
  end
end
