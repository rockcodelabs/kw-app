# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Activities::RoutesController, type: :request do
  let(:active_member) { create(:user, :with_membership, :with_profile) }

  describe 'GET /liga-tradowa(/:year)' do
    context 'when not signed in' do
      it 'is denied' do
        get '/liga-tradowa/2026'

        expect(response).to redirect_to(root_path)
      end
    end

    context 'when active member' do
      before { sign_in active_member }

      it 'renders the requested season' do
        get '/liga-tradowa/2026'

        expect(response).to have_http_status(:success)
        expect(response.body).to include('Liga Tradowa 2026')
      end

      it 'falls back to the current season when the year is omitted' do
        get '/liga-tradowa'

        expect(response).to have_http_status(:success)
        expect(response.body).to include("Liga Tradowa #{Date.current.year}")
      end

      it 'defaults /tradowe-dziki to the 2025 season' do
        get '/tradowe-dziki'

        expect(response).to have_http_status(:success)
        expect(response.body).to include('Liga Tradowa 2025')
      end
    end
  end
end
