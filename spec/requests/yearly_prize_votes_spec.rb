# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Yearly prize votes', type: :request do
  let(:member) { create(:user, :with_membership, :with_profile) }
  let(:edition) { create(:yearly_prize_edition, year: 2026, start_voting_date: 2.days.ago, end_voting_date: 2.days.from_now) }
  let(:nomination) { create(:yearly_prize_request, yearly_prize_edition: edition) }
  let(:params) { { like: { likeable_id: nomination.id, likeable_type: 'Db::YearlyPrizeRequest' } } }

  before { sign_in member }

  it 'records a vote while voting is open' do
    expect { post '/likes', params: params }.to change { member.likes.count }.by(1)
  end

  it 'rejects a second vote in the same edition' do
    create(:like, user: member, likeable: create(:yearly_prize_request, yearly_prize_edition: edition))

    expect { post '/likes', params: params }.not_to(change { member.likes.count })
  end

  it 'rejects votes after the voting end date' do
    edition.update!(end_voting_date: 1.minute.ago)

    expect { post '/likes', params: params }.not_to(change { member.likes.count })
  end

  it 'rejects votes when the edition is closed' do
    edition.update!(closed: true)

    expect { post '/likes', params: params }.not_to(change { member.likes.count })
  end
end
