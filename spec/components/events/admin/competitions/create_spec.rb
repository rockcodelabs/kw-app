# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Events::Admin::Competitions::Create do
  subject(:service) { described_class.new(Events::Competitions::Repository.new, Events::Admin::Competitions::CreateForm.new) }

  let(:inputs) do
    ActionController::Parameters.new(name: 'Zawody', edition_sym: 'zawody', email_text: 'x', event_date: '2027-03-01').permit!
  end

  it 'creates the competition with its default packages' do
    expect { expect(service.call(raw_inputs: inputs)).to eq(Dry::Monads::Success(:success)) }
      .to change(Events::Db::CompetitionRecord, :count).by(1)

    expect(Events::Db::CompetitionRecord.last).to have_attributes(name: 'Zawody', edition_sym: 'zawody', event_date: Date.new(2027, 3, 1))
    expect(Events::Db::CompetitionRecord.last.package_types.count).to eq(2)
  end

  it 'returns full Polish errors and creates nothing when invalid' do
    result = nil

    expect { result = service.call(raw_inputs: ActionController::Parameters.new(inputs.to_h.merge(name: '')).permit!) }
      .not_to change(Events::Db::CompetitionRecord, :count)

    expect(result.failure[:name]).to eq(['name musi być wypełnione'])
  end
end
