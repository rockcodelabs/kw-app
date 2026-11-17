# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Events::Competitions::SignUps::DefaultForm do
  subject(:form) { described_class.new(competition_id: competition.id) }

  let!(:competition) { Events::Db::CompetitionRecord.create!(name: 'Zawody', edition_sym: 'z', email_text: 'x', event_date: 1.month.from_now) }
  let!(:package) { competition.package_types.create!(name: 'Poza KW', cost: 60) }
  let(:params) do
    {
      participant_name_1: 'Jan Kowalski', participant_gender_1: 'male', participant_email_1: 'jan@example.com',
      participant_birth_year_1: '1990', competition_package_type_1_id: package.id.to_s, terms_of_service: '1'
    }
  end

  def messages(locale: :pl, **overrides)
    form.call(params.merge(overrides)).errors(locale: locale).to_h
  end

  it 'accepts valid params' do
    expect(form.call(params)).to be_success
  end

  it 'works without a competition id' do
    expect(described_class.new.call(params)).to be_success
  end

  it 'requires the name' do
    expect(messages(participant_name_1: '')[:participant_name_1]).to eq(['Imię i nazwisko 1 nie może być puste'])
  end

  it 'rejects an invalid e-mail' do
    expect(messages(participant_email_1: 'nope')[:participant_email_1]).to eq(['E-mail 1 jest nieprawidłowy'])
  end

  it 'has English messages' do
    expect(messages(participant_email_1: 'nope', locale: :en)[:participant_email_1]).to eq(['E-mail 1 is invalid'])
  end

  it 'requires the terms to be accepted' do
    expect(messages(terms_of_service: '0')[:terms_of_service]).to eq(['Musisz zaakceptować regulamin!'])
  end

  context 'when the package is Puchar Polski' do
    before { package.update!(name: 'Puchar Polski') }

    it 'requires the license number for Polish participants' do
      expect(messages(participant_country_1: 'pl', participant_license_id_1: '')).to have_key(:participant_license_id_1)
    end

    it 'does not require it for foreign participants' do
      expect(form.call(params.merge(participant_country_1: 'de'))).to be_success
    end

    it 'passes with a license number' do
      expect(form.call(params.merge(participant_country_1: 'pl', participant_license_id_1: '123'))).to be_success
    end
  end
end
