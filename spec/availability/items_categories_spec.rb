# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Availability::Items, 'categories and edge cases' do
  let(:start_date) { '2016-08-25' }
  let(:next_start) { '2016-09-01' }

  before { Timecop.freeze('2016-08-14'.to_date) }
  after { Timecop.return }

  let!(:detector) { create(:item, display_name: 'Detektor lawinowy', rentable_id: 1) }
  let!(:probe)    { create(:item, display_name: 'Sonda', rentable_id: 2) }
  let!(:shovel)   { create(:item, display_name: 'Łopata', rentable_id: 3) }
  let!(:axe)      { create(:item, display_name: 'Czekan', rentable_id: 20) }
  let!(:crampons) { create(:item, display_name: 'Raki', rentable_id: 30) }
  let!(:helmet)   { create(:item, display_name: 'Kask', rentable_id: 40) }

  let(:user) { create(:user) }

  def availability(date = start_date)
    described_class.new(start_date: date)
  end

  describe 'category collectors' do
    it 'splits the available items into detector, probe, shovel, axes, crampons and the rest' do
      a = availability

      expect(a.collect_abc_1).to contain_exactly(detector)
      expect(a.collect_abc_2).to contain_exactly(probe)
      expect(a.collect_abc_3).to contain_exactly(shovel)
      expect(a.collect_axes).to contain_exactly(axe)
      expect(a.collect_crampons).to contain_exactly(crampons)
      expect(a.collect_rest).to contain_exactly(helmet)
    end

    it 'orders items by catalogue number' do
      expect(availability.collect.map(&:rentable_id)).to eq([1, 2, 3, 20, 30, 40])
    end

    it 'drops a reserved item from its category' do
      create(:reservation, user: user, start_date: start_date, end_date: next_start).items << axe

      expect(availability.collect_axes).to be_empty
      expect(availability.collect_rest).to contain_exactly(helmet)
    end
  end

  describe 'which reservations make an item unavailable' do
    def reserve(state:, from:, to:, canceled: false)
      create(:reservation, user: user, state: state, start_date: from, end_date: to, canceled: canceled).tap do |r|
        r.items << axe
      end
    end

    it 'ignores a canceled reservation for the same week' do
      reserve(state: 'reserved', from: start_date, to: next_start, canceled: true)

      expect(availability.collect_axes).to contain_exactly(axe)
    end

    it 'blocks the week of an archived reservation that is paid for that very week' do
      reserve(state: 'archived', from: start_date, to: next_start)

      expect(availability.collect_axes).to be_empty
    end

    it 'is not blocked by an archived (returned) reservation from an earlier week' do
      reserve(state: 'archived', from: '2016-08-18', to: start_date)

      expect(availability.collect_axes).to contain_exactly(axe)
    end

    it 'is blocked for every later week while the earlier reservation is still held' do
      reserve(state: 'holding', from: '2016-08-18', to: start_date)

      expect(availability('2016-08-25').collect_axes).to be_empty
      expect(availability('2016-09-01').collect_axes).to be_empty
      expect(availability('2016-12-01').collect_axes).to be_empty
    end

    it 'blocks only the held item, not the others from the same reservation' do
      held = reserve(state: 'holding', from: '2016-08-18', to: start_date)
      held.items << helmet

      expect(availability.collect).not_to include(axe, helmet)
      expect(availability.collect).to include(detector, probe, shovel, crampons)
    end

    it 'frees the item again after the holder marks it as returned' do
      held = reserve(state: 'holding', from: '2016-08-18', to: start_date)
      held.archive!

      expect(availability.collect_axes).to contain_exactly(axe)
    end

    it 'stays excluded when blocked by both a held and a same-week reservation' do
      reserve(state: 'holding', from: '2016-08-18', to: start_date)
      create(:reservation, user: create(:user), start_date: start_date, end_date: next_start).items << axe

      expect(availability.collect).not_to include(axe)
    end
  end

  describe '#week' do
    it 'spans from the start date to the following Thursday' do
      expect(availability.week).to eq(Date.new(2016, 8, 25)..Date.new(2016, 9, 1))
    end
  end

  describe 'validation of the start date' do
    it 'rejects a date in the past' do
      expect { availability('2016-08-11').collect }.to raise_error('start date cannot be in the past')
    end

    it 'rejects a day other than Thursday' do
      expect { availability('2016-08-26').collect }.to raise_error('start date has to be thursday')
    end
  end
end
