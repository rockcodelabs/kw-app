# frozen_string_literal: true

require 'rails_helper'

# The ski leaderboards must only count routes that have a length (Rails 5.2 meaning of
# `where.not(mountain_routes: { id: nil, length: nil })`, see spec/config/where_not_spec.rb).
RSpec.describe Activities::SkiRepository do
  subject(:repository) { described_class.new }

  let(:with_length)    { create(:user) }
  let(:without_length) { create(:user) }

  def ski_route(user, at, length:)
    create(:mountain_route, :ski, user: user, climbing_date: at.to_date, created_at: at, length: length, boar_length: length.to_i)
      .tap { |route| route.colleagues << user }
  end

  def leaders(relation)
    relation.map(&:id)
  end

  {
    'fetch_current_month'   => ->(repo) { repo.fetch_current_month },
    'fetch_prev_month'      => ->(repo) { repo.fetch_prev_month }
  }.each do |name, call|
    at = name == 'fetch_prev_month' ? -> { Time.zone.now.prev_month.beginning_of_month + 5.days + 12.hours } : -> { Time.zone.now.beginning_of_month + 12.hours }

    it "#{name} lists only users with a route that has a length" do
      ski_route(with_length, at.call, length: 3000)
      ski_route(without_length, at.call, length: nil)

      expect(leaders(call.call(repository))).to eq([with_length.id])
    end
  end

  it 'fetch_specific_month lists only users with a route that has a length' do
    at = Time.zone.local(2026, 2, 10, 12)
    ski_route(with_length, at, length: 3000)
    ski_route(without_length, at, length: nil)

    expect(leaders(repository.fetch_specific_month(2026, 2))).to eq([with_length.id])
  end

  it 'fetch_specific_month_with_gender lists only users with a route that has a length' do
    at = Time.zone.local(2026, 2, 10, 12)
    ski_route(with_length, at, length: 3000)
    ski_route(without_length, at, length: nil)

    expect(leaders(repository.fetch_specific_month_with_gender(nil, 2026, 2))).to eq([with_length.id])
  end

  {
    'fetch_season'  => [->(repo) { repo.fetch_season(year: 2026) }, Time.zone.local(2026, 1, 15, 12)],
    'fetch_winter'  => [->(repo) { repo.fetch_winter(year: 2026) }, Time.zone.local(2026, 1, 15, 12)],
    'fetch_spring'  => [->(repo) { repo.fetch_spring(year: 2026) }, Time.zone.local(2026, 3, 15, 12)],
    'best_of_season' => [->(repo) { repo.best_of_season }, Time.zone.local(2026, 1, 15, 12)],
    'best_route_of_season' => [->(repo) { repo.best_route_of_season }, Time.zone.local(2026, 1, 15, 12)]
  }.each do |name, (call, at)|
    it "#{name} lists only users with a route that has a length" do
      ski_route(with_length, at, length: 3000)
      ski_route(without_length, at, length: nil)

      expect(leaders(call.call(repository))).to eq([with_length.id])
    end
  end
end
