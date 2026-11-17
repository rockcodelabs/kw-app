# frozen_string_literal: true

require 'rails_helper'

# `scope module: 'visiting_card' { resources :profiles, only: :show }` was once drawn before
# the main profiles routes and swallowed /profiles/reactivation and /profiles/new.
RSpec.describe 'Profiles routing', type: :routing do
  it 'routes /profiles/reactivation to the reactivation form' do
    expect(get: '/profiles/reactivation').to route_to(controller: 'profiles', action: 'reactivation')
  end

  it 'routes /profiles/new to the application form' do
    expect(get: '/profiles/new').to route_to(controller: 'profiles', action: 'new')
  end

  it 'routes /profiles/:id to the profile declaration' do
    expect(get: '/profiles/5').to route_to(controller: 'profiles', action: 'show', id: '5')
  end
end
