# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Events::Competitions::SignUpsController', type: :request do
  let(:admin) { create(:user, :admin) }
  let(:custom_form) { nil }
  let!(:competition) do
    Events::Db::CompetitionRecord.create!(
      name: 'Zawody', edition_sym: 'zawody', email_text: 'x', rules_text: 'x', medical_rules_text: 'x', rules: 'x', sign_up_starts_at: 1.day.ago, event_date: 1.month.from_now, custom_form: custom_form
    )
  end
  let!(:package) { competition.package_types.create!(name: 'Poza KW', cost: 60) }

  let(:sign_up) do
    {
      participant_name_1: 'Jan Kowalski',
      participant_gender_1: 'male',
      participant_email_1: 'jan@example.com',
      participant_birth_year_1: '1990',
      competition_package_type_1_id: package.id.to_s,
      terms_of_service: '1'
    }
  end

  describe 'POST create (default form)' do
    it 'creates the sign up' do
      expect { post competition_sign_ups_path(competition), params: { sign_up: sign_up } }
        .to change(Events::Db::SignUpRecord, :count).by(1)

      expect(response).to redirect_to(competition_sign_ups_path(competition.id.to_s))
      expect(Events::Db::SignUpRecord.last).to have_attributes(participant_name_1: 'Jan Kowalski', competition_record_id: competition.id)
    end

    it 're-renders the form with Polish messages when the name is missing' do
      sign_up[:participant_name_1] = ''

      expect { post competition_sign_ups_path(competition), params: { sign_up: sign_up } }
        .not_to change(Events::Db::SignUpRecord, :count)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Imię i nazwisko 1 nie może być puste')
    end

    it 'requires the regulations to be accepted' do
      sign_up[:terms_of_service] = '0'

      expect { post competition_sign_ups_path(competition), params: { sign_up: sign_up } }
        .not_to change(Events::Db::SignUpRecord, :count)

      expect(response.body).to include('Musisz zaakceptować regulamin')
    end

    it 'rejects an invalid e-mail' do
      sign_up[:participant_email_1] = 'nope'

      expect { post competition_sign_ups_path(competition), params: { sign_up: sign_up } }
        .not_to change(Events::Db::SignUpRecord, :count)

      expect(response.body).to include('E-mail 1 jest nieprawidłowy')
    end
  end

  describe 'POST create (tshirt form)' do
    let(:custom_form) { 'tshirt' }

    it 'creates the sign up' do
      params = { sign_up: { participant_name_1: 'Jan', tshirt_size_1: 'M', competition_package_type_1_id: package.id.to_s } }

      expect { post competition_sign_ups_path(competition), params: params }
        .to change(Events::Db::SignUpRecord, :count).by(1)
    end

    it 'fails when the t-shirt size is missing' do
      params = { sign_up: { participant_name_1: 'Jan', tshirt_size_1: '', competition_package_type_1_id: package.id.to_s } }

      expect { post competition_sign_ups_path(competition), params: params }
        .not_to change(Events::Db::SignUpRecord, :count)

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST create (mas form)' do
    let(:custom_form) { 'mas' }

    let(:mas_params) do
      sign_up.merge(
        team_name: 'Zespół',
        participant_phone_1: '123456789',
        participant_name_2: 'Anna Nowak',
        participant_phone_2: '987654321',
        participant_gender_2: 'female',
        participant_email_2: 'anna@example.com',
        participant_birth_year_2: '1992',
        competition_package_type_2_id: package.id.to_s
      )
    end

    it 'creates the team sign up' do
      expect { post competition_sign_ups_path(competition), params: { sign_up: mas_params } }
        .to change(Events::Db::SignUpRecord, :count).by(1)
    end

    it 'requires an active membership for a membership package' do
      package.update!(membership: true)
      mas_params[:participant_kw_id_1] = '99999'

      expect { post competition_sign_ups_path(competition), params: { sign_up: mas_params } }
        .not_to change(Events::Db::SignUpRecord, :count)

      expect(response.body).to include('Musisz podać numer legitymacji klubu 1 z opłaconą składką')
    end

    it 'requires the team name' do
      mas_params[:team_name] = ''

      expect { post competition_sign_ups_path(competition), params: { sign_up: mas_params } }
        .not_to change(Events::Db::SignUpRecord, :count)

      expect(response.body).to include('Musisz podać nazwę zespołu')
    end
  end

  describe 'POST create (mjs form)' do
    let(:custom_form) { 'mjs' }

    let(:mjs_params) do
      sign_up.merge(
        participant_first_name_1: 'Jan',
        participant_country_1: 'pl',
        participant_phone_1: '123456789',
        participant_phone_2: '987654321',
        medical_rules: '1'
      )
    end

    it 'creates the sign up' do
      expect { post competition_sign_ups_path(competition), params: { sign_up: mjs_params } }
        .to change(Events::Db::SignUpRecord, :count).by(1)
    end

    it 'requires the medical clause to be accepted' do
      mjs_params[:medical_rules] = '0'

      expect { post competition_sign_ups_path(competition), params: { sign_up: mjs_params } }
        .not_to change(Events::Db::SignUpRecord, :count)

      expect(response.body).to include('klauzulą informacyjną')
    end

    it 'rejects a participant younger than the junior year of the package' do
      package.update!(junior_year: 2000)

      expect { post competition_sign_ups_path(competition), params: { sign_up: mjs_params } }
        .not_to change(Events::Db::SignUpRecord, :count)
    end
  end

  describe 'PUT update' do
    before { sign_in admin }

    let!(:record) do
      Events::Db::SignUpRecord.create!(
        participant_name_1: 'Jan Kowalski', participant_gender_1: 'male', participant_email_1: 'jan@example.com',
        participant_birth_year_1: '1990', competition_package_type_1_id: package.id, competition_record_id: competition.id
      ).tap { |r| r.create_payment(dotpay_id: 'x') }
    end

    it 'updates the sign up' do
      put competition_sign_up_path(competition, record), params: { sign_up: sign_up.merge(participant_name_1: 'Nowe Imie') }

      expect(response).to redirect_to(edit_competition_sign_up_path(competition_id: competition.id.to_s, id: record.id))
      expect(record.reload.participant_name_1).to eq('Nowe Imie')
    end

    it 're-renders the form on invalid data' do
      put competition_sign_up_path(competition, record), params: { sign_up: sign_up.merge(participant_name_1: '') }

      expect(response).to have_http_status(:ok)
      expect(record.reload.participant_name_1).to eq('Jan Kowalski')
    end
  end
end
