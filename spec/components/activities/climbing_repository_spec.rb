# frozen_string_literal: true

require 'rails_helper'

# The climbing ("Dziki") leaderboards count a route only when it has a length AND its difficulty is not in
# EXCLUDED_DIFFICULTY (Rails 5.2 meaning of the chained conditions, see spec/config/where_not_spec.rb).
# On Rails 7 the multi-key form counted 17 % more regular-climbing routes on the restored prod data.
RSpec.describe Activities::ClimbingRepository do
  subject(:repository) { described_class.new(year: 2024) }

  let(:qualifying) { create(:user) }
  let(:too_easy)   { create(:user) }
  let(:no_length)  { create(:user) }
  let(:at)         { Time.zone.local(2024, 7, 10, 12) }

  def climbing_route(user, difficulty:, length: 800, **attrs)
    create(:mountain_route, user: user, route_type: :regular_climbing, climbing_date: at.to_date, created_at: at,
                            length: length, difficulty: difficulty, **attrs).tap { |route| route.colleagues << user }
  end

  let!(:good_route)   { climbing_route(qualifying, difficulty: 'V', hearts_count: 3, description: '#exploratortatr') }
  let!(:easy_route)   { climbing_route(too_easy, difficulty: 'II', hearts_count: 5, description: '#exploratortatr') }
  let!(:no_length_route) { climbing_route(no_length, difficulty: 'V', length: nil, hearts_count: 7, description: '#exploratortatr') }
  let!(:no_grade_route) { climbing_route(create(:user), difficulty: nil, hearts_count: 9, description: '#exploratortatr') }

  describe '#best_of_season' do
    it 'ranks only users with a qualifying route' do
      expect(repository.best_of_season.map(&:id)).to eq([qualifying.id])
    end
  end

  describe '#best_route_of_season' do
    it 'lists only qualifying routes' do
      expect(repository.best_route_of_season.map(&:id)).to eq([good_route.id])
    end
  end

  describe '#tatra_uniqe' do
    it 'lists only users with a qualifying route' do
      expect(repository.tatra_uniqe).to eq([qualifying])
    end
  end

  describe '#season_teams' do
    it 'counts only qualifying routes' do
      [good_route, easy_route, no_length_route].each { |route| route.colleagues << create(:user) }

      teams = repository.season_teams

      expect(teams.size).to eq(1)
      expect(teams.first).to include(routes_count: 1, meters: 800)
    end
  end

  describe '#hall_of_fame' do
    it 'names a champion only from qualifying routes' do
      expect(repository.hall_of_fame.map { |row| [row[:year], row[:user].id, row[:meters]] })
        .to eq([[2024, qualifying.id, 800]])
    end
  end

  describe '#available_years' do
    it 'lists a season only when it has a qualifying route' do
      later = create(:user)
      create(:mountain_route, user: later, route_type: :regular_climbing, climbing_date: Date.new(2023, 7, 1),
                              created_at: Time.zone.local(2023, 7, 1), length: 500, difficulty: '0+').colleagues << later
      create(:mountain_route, user: later, route_type: :regular_climbing, climbing_date: Date.new(2022, 7, 1),
                              created_at: Time.zone.local(2022, 7, 1), length: nil, difficulty: 'V').colleagues << later

      years = described_class.new(year: 2021).available_years

      expect(years).to include(2024)
      expect(years).not_to include(2023, 2022)
    end
  end

  describe '#season_rows' do
    it 'lists only users with a qualifying route' do
      expect(repository.season_rows.map { |row| row[:user].id }).to eq([qualifying.id])
    end
  end
end
