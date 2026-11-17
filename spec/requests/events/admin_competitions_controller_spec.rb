# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Events::Admin::CompetitionsController', type: :request do
  let(:admin) { create(:user, :admin) }

  let(:params) do
    { competition: { name: 'Zawody', edition_sym: 'zawody_2027', email_text: 'Dziękujemy', event_date: '2027-03-01' } }
  end

  before { sign_in admin }

  describe 'POST create' do
    it 'creates a competition with default package types' do
      expect { post admin_competitions_path, params: params }
        .to change(Events::Db::CompetitionRecord, :count).by(1)

      expect(response).to redirect_to(admin_competitions_path)
      expect(Events::Db::CompetitionRecord.last).to have_attributes(name: 'Zawody', edition_sym: 'zawody_2027')
      expect(Events::Db::CompetitionRecord.last.event_date).to be_present
      expect(Events::Db::CompetitionRecord.last.package_types.count).to eq(2)
    end

    it 're-renders the form with a flash error when the name is missing' do
      params[:competition][:name] = ''

      expect { post admin_competitions_path, params: params }
        .not_to change(Events::Db::CompetitionRecord, :count)

      expect(response).to have_http_status(:ok)
      expect(flash[:error]).to include('musi być wypełnione')
    end
  end

  describe 'PUT update' do
    let!(:competition) do
      Events::Db::CompetitionRecord.create!(name: 'Stare', edition_sym: 'stare', email_text: 'x', event_date: '2027-01-01')
    end

    it 'updates the competition' do
      put admin_competition_path(competition), params: params

      expect(response).to redirect_to(edit_admin_competition_path(competition.id))
      expect(competition.reload.name).to eq('Zawody')
    end

    it 'redirects with an error when the data is invalid' do
      params[:competition][:email_text] = ''

      put admin_competition_path(competition), params: params

      expect(response).to redirect_to(admin_competitions_path)
      expect(flash[:error]).to include('musi być wypełnione')
      expect(competition.reload.name).to eq('Stare')
    end
  end
end
