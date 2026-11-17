# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Events::Admin::Competitions::Update do
  subject(:service) { described_class.new(Events::Competitions::Repository.new, Events::Admin::Competitions::CreateForm.new) }

  let!(:competition) do
    Events::Db::CompetitionRecord.create!(name: 'Stare', edition_sym: 'stare', email_text: 'x', event_date: '2027-01-01')
  end
  let(:inputs) do
    ActionController::Parameters.new(name: 'Nowe', edition_sym: 'stare', email_text: 'x', event_date: '2027-03-01').permit!
  end

  it 'updates the competition' do
    result = service.call(id: competition.id, raw_inputs: inputs)

    expect(result).to eq(Dry::Monads::Success(:success))
    expect(competition.reload).to have_attributes(name: 'Nowe', event_date: Date.new(2027, 3, 1))
  end

  it 'returns full Polish errors and keeps the competition when invalid' do
    result = service.call(id: competition.id, raw_inputs: ActionController::Parameters.new(inputs.to_h.merge(email_text: '')).permit!)

    expect(result.failure[:email_text]).to eq(['email_text musi być wypełnione'])
    expect(competition.reload.name).to eq('Stare')
  end
end
