# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Training::Activities::CreateSkiRoute do
  subject(:service) { described_class.new(Training::Activities::Repository.new, Training::Activities::SkiRouteForm) }

  let(:member) { create(:user, :with_membership, :with_profile) }
  let(:friend) { create(:user, :with_membership, :with_profile) }
  let(:inputs) do
    { name: 'Tura', climbing_date: Date.current.to_s, rating: '3', colleague_ids: ['', member.id.to_s, friend.id.to_s] }
  end

  it 'creates the route for the user' do
    expect { expect(service.call(raw_inputs: inputs, user_id: member.id)).to be_success }
      .to change(Db::Activities::MountainRoute, :count).by(1)

    expect(Db::Activities::MountainRoute.last).to have_attributes(name: 'Tura', user_id: member.id)
  end

  it 'notifies colleagues other than the author' do
    expect { service.call(raw_inputs: inputs, user_id: member.id) }
      .to change(NotificationCenter::NotificationRecord, :count).by(1)

    expect(NotificationCenter::NotificationRecord.last).to have_attributes(
      recipient_id: friend.id, actor_id: member.id, action: 'assigned_to_route'
    )
  end

  it 'returns Polish errors and creates nothing when the name is blank' do
    result = nil

    expect { result = service.call(raw_inputs: inputs.merge(name: ''), user_id: member.id) }
      .not_to change(Db::Activities::MountainRoute, :count)

    expect(result).to be_failure
    expect(result.failure[:name]).to eq(['Nazwa przejścia musi być podana'])
  end

  it 'fails when colleagues are missing' do
    result = service.call(raw_inputs: inputs.except(:colleague_ids), user_id: member.id)

    expect(result).to be_failure
    expect(result.failure).to have_key(:colleague_ids)
  end
end
