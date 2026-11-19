# frozen_string_literal: true

require 'rails_helper'

# Same contract as Activities::SkiRepository, for the older Training::Activities::Repository leaderboards.
RSpec.describe Training::Activities::Repository do
  subject(:repository) { described_class.new }

  let(:with_length)    { create(:user) }
  let(:without_length) { create(:user) }

  def ski_route(user, at, length:)
    create(:mountain_route, :ski, user: user, climbing_date: at.to_date, created_at: at, length: length, boar_length: length.to_i)
      .tap { |route| route.colleagues << user }
  end

  {
    'fetch_current_month'   => [->(repo) { repo.fetch_current_month }, -> { Time.zone.now.beginning_of_month + 12.hours }],
    'fetch_prev_month'      => [->(repo) { repo.fetch_prev_month }, -> { Time.zone.now.prev_month.beginning_of_month + 5.days + 12.hours }],
    'fetch_prev_prev_month' => [->(repo) { repo.fetch_prev_prev_month }, -> { Time.zone.now.prev_month.beginning_of_month + 5.days + 12.hours }],
    'fetch_autum'           => [->(repo) { repo.fetch_autum }, -> { Time.zone.local(2025, 12, 15, 12) }],
    'fetch_winter'          => [->(repo) { repo.fetch_winter }, -> { Time.zone.local(2026, 1, 15, 12) }],
    'fetch_spring'          => [->(repo) { repo.fetch_spring }, -> { Time.zone.local(2026, 3, 15, 12) }],
    'fetch_season'          => [->(repo) { repo.fetch_season }, -> { Time.zone.local(2026, 1, 15, 12) }]
  }.each do |name, (call, at)|
    it "#{name} lists only users with a route that has a length" do
      ski_route(with_length, at.call, length: 3000)
      ski_route(without_length, at.call, length: nil)

      expect(call.call(repository).map(&:id)).to eq([with_length.id])
    end
  end
end
