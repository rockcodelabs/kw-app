# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Membership application (ProfilesController)', type: :request do
  describe 'GET /zgloszenie' do
    it 'renders the application form' do
      get '/zgloszenie'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('profile[birth_date]')
    end
  end

  describe 'GET /application' do
    it 'renders the English application form' do
      get '/application'

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /profiles/reactivation' do
    it 'renders the reactivation form' do
      get '/profiles/reactivation'

      expect(response).to have_http_status(:ok)
    end
  end
end
