# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Training::Activities::SkiRouteForm do
  subject(:result) { described_class.new.call(params) }

  let(:params) { { name: 'Tura', climbing_date: '2026-01-01', colleague_ids: ['1'], gps_tracks: tracks } }
  let(:tracks) { [] }

  def upload(filename)
    Struct.new(:original_filename).new(filename)
  end

  it 'is valid without gps tracks' do
    expect(result).to be_success
  end

  context 'with a .gpx track' do
    let(:tracks) { [upload('trasa.gpx')] }

    it { is_expected.to be_success }
  end

  context 'with a track without the .gpx extension' do
    let(:tracks) { [upload('trasa.txt')] }

    it 'fails with the Polish extension message' do
      expect(result).to be_failure
      expect(result.errors(locale: :pl).to_h[:gps_tracks]).to eq(['Track musi posiadać rozszerzenie .gpx!'])
    end
  end

  context 'with blank entries only' do
    let(:tracks) { [''] }

    it { is_expected.to be_success }
  end
end
