# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Photo competition votes', type: :request do
  let(:member) { create(:user, :with_membership, :with_profile) }
  let(:edition) { create(:photo_competition_edition, start_voting_date: 2.days.ago, end_voting_date: 2.days.from_now) }
  let(:photo) { create(:photo_competition_request, edition: edition) }
  let(:params) { { like: { likeable_id: photo.id, likeable_type: 'PhotoCompetition::RequestRecord' } } }

  before { sign_in member }

  it 'records a vote while voting is open' do
    expect { post '/likes', params: params }.to change { member.likes.count }.by(1)
  end

  it 'allows 3 votes per edition and rejects the 4th' do
    3.times { create(:like, user: member, likeable: create(:photo_competition_request, edition: edition)) }

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
