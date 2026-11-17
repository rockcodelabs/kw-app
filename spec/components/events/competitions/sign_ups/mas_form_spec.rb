# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Events::Competitions::SignUps::MasForm do
  subject(:form) { described_class.new(competition_id: competition.id) }

  let!(:competition) { Events::Db::CompetitionRecord.create!(name: 'Zawody', edition_sym: 'z', email_text: 'x', event_date: 1.month.from_now) }
  let!(:package) { competition.package_types.create!(name: 'Poza KW', cost: 60) }
  let(:params) do
    {
      team_name: 'Zespół', terms_of_service: '1',
      participant_name_1: 'Jan Kowalski', participant_phone_1: '123', participant_gender_1: 'male',
      participant_email_1: 'jan@example.com', participant_birth_year_1: '1990', competition_package_type_1_id: package.id.to_s,
      participant_name_2: 'Anna Nowak', participant_phone_2: '456', participant_gender_2: 'female',
      participant_email_2: 'anna@example.com', participant_birth_year_2: '1992', competition_package_type_2_id: package.id.to_s
    }
  end

  def messages(overrides = {})
    form.call(params.merge(overrides)).errors(locale: :pl).to_h
  end

  it 'accepts a valid team' do
    expect(form.call(params)).to be_success
  end

  it 'requires the team name' do
    expect(messages(team_name: '')[:team_name]).to eq(['Musisz podać nazwę zespołu'])
  end

  it 'requires the second participant' do
    expect(messages(participant_name_2: '')[:participant_name_2]).to eq(['Imię i nazwisko 2 nie może być puste'])
  end

  it 'validates both e-mails' do
    expect(messages(participant_email_2: 'x')[:participant_email_2]).to eq(['E-mail 2 jest nieprawidłowy'])
  end

  it 'requires the terms to be accepted' do
    expect(messages(terms_of_service: '0')).to have_key(:terms_of_service)
  end

  context 'with a membership package' do
    before { package.update!(membership: true) }

    it 'requires active members for both participants' do
      errors = messages(participant_kw_id_1: '99999', participant_kw_id_2: '88888')

      expect(errors[:participant_kw_id_1]).to eq(['Musisz podać numer legitymacji klubu 1 z opłaconą składką'])
      expect(errors[:participant_kw_id_2]).to eq(['Musisz podać numer legitymacji klubu 2 z opłaconą składką'])
    end
  end
end
