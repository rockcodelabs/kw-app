# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Events::Competitions::SignUps::MjsForm do
  subject(:form) { described_class.new(competition_id: competition.id) }

  let!(:competition) { Events::Db::CompetitionRecord.create!(name: 'Zawody', edition_sym: 'z', email_text: 'x', event_date: 1.month.from_now) }
  let!(:package) { competition.package_types.create!(name: 'Poza KW', cost: 60) }
  let(:params) do
    {
      participant_first_name_1: 'Jan', participant_name_1: 'Kowalski', participant_country_1: 'pl',
      participant_phone_1: '123', participant_phone_2: '456', participant_gender_1: 'male',
      participant_email_1: 'jan@example.com', participant_birth_year_1: '1990',
      competition_package_type_1_id: package.id.to_s, terms_of_service: '1', medical_rules: '1'
    }
  end

  def messages(overrides = {})
    form.call(params.merge(overrides)).errors(locale: :pl).to_h
  end

  it 'accepts valid params' do
    expect(form.call(params)).to be_success
  end

  it 'requires the emergency phone' do
    expect(messages(participant_phone_2: '')[:participant_phone_2]).to be_present
  end

  it 'requires the medical clause to be accepted' do
    expect(messages(medical_rules: '0')[:medical_rules]).to eq(['Zapoznaj się z klauzulą informacyjną dotyczącą przetwarzania danych osobowych!'])
  end

  it 'requires the terms to be accepted' do
    expect(messages(terms_of_service: '0')).to have_key(:terms_of_service)
  end

  it 'rejects a participant older than the junior category' do
    package.update!(junior_year: 2000)

    expect(messages(participant_birth_year_1: '1990')[:participant_birth_year_1]).to eq(['Uczestnik 1 jest starszy niż kategoria Junior'])
  end

  it 'accepts a participant within the junior category' do
    package.update!(junior_year: 2000)

    expect(form.call(params.merge(participant_birth_year_1: '2005'))).to be_success
  end

  it 'requires an active member for a membership package' do
    package.update!(membership: true)

    expect(messages(participant_kw_id_1: '99999')[:participant_kw_id_1]).to be_present
  end
end
