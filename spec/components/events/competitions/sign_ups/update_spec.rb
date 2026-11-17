# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Events::Competitions::SignUps::Update do
  subject(:service) { described_class.new(Events::Competitions::Repository.new, competition.form) }

  let!(:competition) { Events::Db::CompetitionRecord.create!(name: 'Zawody', edition_sym: 'z', email_text: 'x', event_date: 1.month.from_now) }
  let!(:package) { competition.package_types.create!(name: 'Poza KW', cost: 60) }
  let!(:sign_up) do
    Events::Db::SignUpRecord.create!(
      participant_name_1: 'Jan Kowalski', participant_gender_1: 'male', participant_email_1: 'jan@example.com',
      participant_birth_year_1: '1990', competition_package_type_1_id: package.id, competition_record_id: competition.id
    )
  end
  let(:inputs) do
    {
      participant_name_1: 'Nowe Imie', participant_gender_1: 'male', participant_email_1: 'jan@example.com',
      participant_birth_year_1: '1990', competition_package_type_1_id: package.id.to_s, terms_of_service: '1'
    }
  end

  def call(overrides = {})
    service.call(
      competition_id: competition.id, sign_up_record_id: sign_up.id,
      raw_inputs: ActionController::Parameters.new(inputs.merge(overrides)).permit!
    )
  end

  it 'updates the sign up' do
    expect(call).to eq(Dry::Monads::Success(:success))
    expect(sign_up.reload.participant_name_1).to eq('Nowe Imie')
  end

  it 'returns Polish errors and leaves the record unchanged when invalid' do
    result = call(participant_name_1: '')

    expect(result).to be_failure
    expect(result.failure[:participant_name_1]).to eq(['Imię i nazwisko 1 nie może być puste'])
    expect(sign_up.reload.participant_name_1).to eq('Jan Kowalski')
  end

  it 'raises for an unknown sign up' do
    expect do
      service.call(competition_id: competition.id, sign_up_record_id: 0, raw_inputs: ActionController::Parameters.new(inputs).permit!)
    end.to raise_error(ActiveRecord::RecordNotFound)
  end
end
