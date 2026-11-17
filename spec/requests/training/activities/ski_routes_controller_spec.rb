# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Training::Activities::SkiRoutesController', type: :request do
  let(:member) { create(:user, :with_membership, :with_profile) }
  let(:friend) { create(:user, :with_membership, :with_profile) }

  def ski_route_params(overrides = {})
    {
      ski_route: {
        name: 'Czerwone Wierchy',
        climbing_date: Date.current.to_s,
        rating: '3',
        colleague_ids: ['', member.id.to_s, friend.id.to_s]
      }.merge(overrides)
    }
  end

  before { sign_in member }

  describe 'POST create' do
    it 'creates a ski route and notifies colleagues' do
      expect { post activities_ski_routes_path, params: ski_route_params }
        .to change(Db::Activities::MountainRoute, :count).by(1)
        .and change(NotificationCenter::NotificationRecord, :count).by(1)

      expect(response).to redirect_to(activities_mountain_routes_path)
      expect(Db::Activities::MountainRoute.last).to have_attributes(name: 'Czerwone Wierchy', user_id: member.id)
    end

    it 're-renders the form with a Polish message when the name is missing' do
      expect { post activities_ski_routes_path, params: ski_route_params(name: '') }
        .not_to change(Db::Activities::MountainRoute, :count)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Nazwa przejścia musi być podana')
    end

    it 're-renders the form when colleagues are missing' do
      params = ski_route_params
      params[:ski_route].delete(:colleague_ids)

      expect { post activities_ski_routes_path, params: params }
        .not_to change(Db::Activities::MountainRoute, :count)

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'PUT update' do
    let!(:route) { create(:mountain_route, :ski, user: member) }

    before { route.colleagues << member }

    it 'updates the route' do
      put activities_ski_route_path(route.id), params: ski_route_params(name: 'Nowa nazwa')

      expect(response).to redirect_to(edit_activities_ski_route_path(route.id))
      expect(route.reload.name).to eq('Nowa nazwa')
    end

    it 're-renders the form with errors on invalid data' do
      put activities_ski_route_path(route.id), params: ski_route_params(name: '')

      expect(response).to have_http_status(:ok)
      expect(route.reload.name).not_to eq('')
    end
  end
end
