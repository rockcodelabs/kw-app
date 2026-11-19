# frozen_string_literal: true

require 'rails_helper'

# GET /api/dashboard is public. `latest_degree` (TOPR avalanche degree image, last row from 2021) was removed
# together with the weather scrapers.
RSpec.describe Blog::Dashboard do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user) }

  before do
    travel_to Time.zone.local(2026, 2, 10, 12)
    route = create(:mountain_route, :ski, user: user, climbing_date: Date.new(2026, 2, 1), created_at: Time.zone.local(2026, 2, 1, 12),
                                          length: 3000, name: 'Ski Route')
    route.colleagues << user
  end

  after { travel_back }

  it 'returns the ski totals and no scraper data' do
    data = JSON.parse(described_class.new.fetch)

    expect(data.keys).to contain_exactly('total_meters', 'last_route', 'max_meters_person')
    expect(data['total_meters']).to eq(3000)
    expect(data['last_route']).to include('name' => 'Ski Route', 'date' => '2026-02-01')
    expect(data['max_meters_person']).to include('name' => user.display_name, 'meters' => 3000)
  end
end
