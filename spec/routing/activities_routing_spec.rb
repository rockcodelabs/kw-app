# frozen_string_literal: true

require 'rails_helper'

# These routes came from master (app/components/activities/routes.rb, a file that
# develop moved to config/routes/custom_endpoints.rb). The merge of master into
# develop has to keep them: the top bar links to /liga-tradowa/2026 and the
# Gorskie Dziki profile page needs /gorskie-dziki/dzik/:kw_id.
RSpec.describe 'Activities routing', type: :routing do
  it 'routes /liga-tradowa to the trad league' do
    expect(get: '/liga-tradowa').to route_to(controller: 'activities/routes', action: 'liga_tradowa')
  end

  it 'routes /liga-tradowa/:year to the trad league for that season' do
    expect(get: '/liga-tradowa/2026').to route_to(controller: 'activities/routes', action: 'liga_tradowa', year: '2026')
  end

  it 'defaults /tradowe-dziki to the 2025 season' do
    expect(get: '/tradowe-dziki').to route_to(controller: 'activities/routes', action: 'liga_tradowa', year: '2025')
  end

  it 'routes /gorskie-dziki to the current season' do
    expect(get: '/gorskie-dziki').to route_to(controller: 'activities/routes', action: 'gorskie_dziki')
  end

  it 'routes /gorskie-dziki/:year to a four-digit season only' do
    expect(get: '/gorskie-dziki/2025').to route_to(controller: 'activities/routes', action: 'gorskie_dziki', year: '2025')
    expect(get: '/gorskie-dziki/regulamin').to route_to(controller: 'activities/routes', action: 'gorskie_dziki_regulamin')
  end

  it 'routes /gorskie-dziki/dzik/:kw_id to a boar profile' do
    expect(get: '/gorskie-dziki/dzik/123').to route_to(controller: 'activities/routes', action: 'gorskie_dziki_profile', kw_id: '123')
  end
end
