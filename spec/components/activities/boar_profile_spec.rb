# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Activities::BoarProfile do
  subject(:profile) { described_class.new(user: user, year: 2024) }

  let(:user) { create(:user) }

  def route(difficulty:, length: 800)
    create(:mountain_route, user: user, route_type: :regular_climbing, climbing_date: Date.new(2024, 7, 10),
                            created_at: Time.zone.local(2024, 7, 10, 12), length: length, difficulty: difficulty)
      .tap { |created| created.colleagues << user }
  end

  let!(:qualifying) { route(difficulty: 'V') }
  let!(:too_easy)   { route(difficulty: 'II', length: 500) }
  let!(:no_length)  { route(difficulty: 'V', length: nil) }
  let!(:no_grade)   { route(difficulty: nil, length: 300) }

  it 'counts only routes with a length and a difficulty that is not excluded' do
    expect(profile.routes).to eq([qualifying])
    expect(profile.total_meters).to eq(800)
  end

  it 'builds the meters history from the same routes' do
    history = profile.history.find { |row| row[:year] == 2024 }

    expect(history[:meters]).to eq(800)
  end
end
