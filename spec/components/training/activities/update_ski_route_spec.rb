# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Training::Activities::UpdateSkiRoute do
  subject(:service) { described_class.new(Training::Activities::Repository.new, Training::Activities::SkiRouteForm) }

  let(:member) { create(:user, :with_membership, :with_profile) }
  let!(:route) { create(:mountain_route, user: member, route_type: 'ski', name: 'Stara') }
  let(:inputs) { { name: 'Nowa', climbing_date: Date.current.to_s, rating: '3', colleague_ids: [member.id.to_s] } }

  it 'updates the route' do
    result = service.call(id: route.id, raw_inputs: inputs, user_id: member.id)

    expect(result).to eq(Dry::Monads::Success(:success))
    expect(route.reload.name).to eq('Nowa')
  end

  it 'returns Polish errors and leaves the route unchanged when invalid' do
    result = service.call(id: route.id, raw_inputs: inputs.merge(name: ''), user_id: member.id)

    expect(result).to be_failure
    expect(result.failure[:name]).to eq(['Nazwa przejścia musi być podana'])
    expect(route.reload.name).to eq('Stara')
  end
end
