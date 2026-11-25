# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Availability::Items do
  let(:start_date) { '2016-08-25' }
  
  before { Timecop.freeze('2016-08-14'.to_date) }
  after { Timecop.return }
  
  # Create items with different owners
  let!(:item_kw_1) { create(:item, :kw_owned, rentable: true) }
  let!(:item_kw_2) { create(:item, :kw_owned, rentable: true) }
  let!(:item_snw) { create(:item, :snw_owned, rentable: true) }
  let!(:item_not_rentable) { create(:item, :sww_owned, rentable: false) }
  let!(:item_instructors) { create(:item, :instructors_owned, rentable: true) }
  let!(:item_sww) { create(:item, :sww_owned, rentable: true) }
  
  let!(:user1) { create(:user) }
  let!(:user2) { create(:user) }
  
  before do
    # Reserve some items for the start_date
    reservation1 = create(:reservation,
      user: user1,
      start_date: start_date,
      end_date: start_date.to_date + 7
    )
    reservation1.items << item_kw_1
    reservation1.items << item_kw_2
    
    reservation2 = create(:reservation,
      user: user2,
      start_date: start_date,
      end_date: start_date.to_date + 7
    )
    reservation2.items << item_sww
  end
  
  subject { described_class.new(start_date: start_date).collect }

  context 'start_date in the past' do
    let(:start_date) { '2016-08-01' }

    it 'returns warning' do
      expect { subject }.to raise_error('start date cannot be in the past')
    end
  end

  context 'start_date is not thursday' do
    let(:start_date) { '2016-09-24' }

    it 'returns warning' do
      expect { subject }.to raise_error('start date has to be thursday')
    end
  end

  it 'excludes not available, instructors and not rentale items' do
    # Should only return item_snw (rentable, snw owned, not reserved)
    # Excludes: item_kw_1 & item_kw_2 (reserved), item_not_rentable (not rentable),
    # item_instructors (instructors owned), item_sww (reserved)
    expect(subject).to match_array([item_snw])
  end

  context 'item given out in an earlier week and not returned yet' do
    let!(:holder) { create(:user) }
    let(:earlier_start) { '2016-08-18' }
    let!(:held_reservation) do
      create(:reservation, user: holder, state: 'holding', start_date: earlier_start,
                           end_date: earlier_start.to_date + 7).tap { |r| r.items << item_snw }
    end

    it 'stays unavailable in later weeks' do
      expect(subject).to eq([])
    end

    it 'is available again once marked as returned (archived)' do
      held_reservation.archive!

      expect(subject).to match_array([item_snw])
    end

    it 'is still unavailable when the later reservation already exists' do
      expect(described_class.new(start_date: '2016-09-01').collect).not_to include(item_snw)
    end
  end

  context 'item reserved in an earlier week but never given out' do
    let!(:reservation) do
      create(:reservation, user: user1, state: 'reserved', start_date: '2016-08-18',
                           end_date: '2016-08-25').tap { |r| r.items << item_snw }
    end

    it 'stays available' do
      expect(subject).to match_array([item_snw])
    end
  end

  context 'item given out in a later week' do
    let!(:reservation) do
      create(:reservation, user: user1, state: 'holding', start_date: '2016-09-01',
                           end_date: '2016-09-08').tap { |r| r.items << item_snw }
    end

    it 'is not blocked in an earlier week' do
      expect(subject).to match_array([item_snw])
    end
  end
end