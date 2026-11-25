# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Db::Reservation do
  let(:user) { create(:user, kw_id: 4321, first_name: 'Anna', last_name: 'Kowalska') }

  def make(attrs = {})
    create(:reservation, { user: user }.merge(attrs))
  end

  describe 'workflow' do
    subject(:reservation) { make }

    it 'starts as reserved' do
      expect(reservation).to be_reserved
      expect(reservation.state).to eq('reserved')
    end

    it 'goes reserved -> holding with give!' do
      reservation.give!

      expect(reservation.reload).to be_holding
    end

    it 'goes holding -> archived with archive!' do
      reservation.give!
      reservation.archive!

      expect(reservation.reload).to be_archived
    end

    it 'can be archived straight from reserved (never picked up)' do
      reservation.archive!

      expect(reservation.reload).to be_archived
    end

    it 'cannot be given twice' do
      reservation.give!

      expect { reservation.give! }.to raise_error(Workflow::NoTransitionAllowed)
    end

    it 'cannot be given or archived again once archived' do
      reservation.archive!

      expect { reservation.give! }.to raise_error(Workflow::NoTransitionAllowed)
      expect { reservation.archive! }.to raise_error(Workflow::NoTransitionAllowed)
    end
  end

  describe 'state scopes' do
    let!(:reserved)  { make }
    let!(:holding)   { make.tap(&:give!) }
    let!(:archived)  { make.tap(&:archive!) }

    it '.reserved / .holding / .archived pick one state each' do
      expect(described_class.reserved).to contain_exactly(reserved)
      expect(described_class.holding).to contain_exactly(holding)
      expect(described_class.archived).to contain_exactly(archived)
    end

    it '.not_archived and .not_reserved exclude their state' do
      expect(described_class.not_archived).to contain_exactly(reserved, holding)
      expect(described_class.not_reserved).to contain_exactly(holding, archived)
    end
  end

  describe '.holding_until' do
    let(:thursday) { Date.new(2026, 12, 10) }

    it 'includes given-out reservations that started on or before the date' do
      same_week = make(state: 'holding', start_date: thursday, end_date: thursday + 7)
      earlier   = make(state: 'holding', start_date: thursday - 14, end_date: thursday - 7)

      expect(described_class.holding_until(thursday)).to contain_exactly(same_week, earlier)
    end

    it 'excludes reservations that start after the date' do
      make(state: 'holding', start_date: thursday + 7, end_date: thursday + 14)

      expect(described_class.holding_until(thursday)).to be_empty
    end

    it 'excludes reserved (not picked up) and archived (returned) reservations' do
      make(state: 'reserved', start_date: thursday - 14, end_date: thursday - 7)
      make(state: 'archived', start_date: thursday - 14, end_date: thursday - 7)

      expect(described_class.holding_until(thursday)).to be_empty
    end

    it 'stops matching once the reservation is archived' do
      held = make(state: 'holding', start_date: thursday - 7, end_date: thursday)
      expect(described_class.holding_until(thursday)).to contain_exactly(held)

      held.archive!

      expect(described_class.holding_until(thursday)).to be_empty
    end
  end

  describe '.expire_tomorrow' do
    it 'matches reservations whose end date was yesterday' do
      due = make(end_date: 1.day.ago.to_date)
      make(end_date: Date.current)

      expect(described_class.expire_tomorrow).to contain_exactly(due)
    end
  end

  describe 'payment scopes' do
    def with_payment(attrs)
      make.tap { |r| r.create_payment({ dotpay_id: SecureRandom.hex(13) }.merge(attrs)) }
    end

    let!(:unpaid)       { with_payment(state: 'unpaid') }
    let!(:online)       { with_payment(state: 'prepaid') }
    let!(:cash_prepaid) { with_payment(state: 'prepaid', cash: true) }

    it '.not_prepaid excludes prepaid payments' do
      expect(described_class.not_prepaid).to contain_exactly(unpaid)
    end

    it '.not_cash excludes cash payments' do
      expect(described_class.not_cash).to contain_exactly(unpaid, online)
    end

    it '.cash_prepaid keeps only cash payments' do
      expect(described_class.cash_prepaid).to contain_exactly(cash_prepaid)
    end
  end

  describe 'default order' do
    it 'sorts by start_date' do
      later   = make(start_date: '2016-09-01', end_date: '2016-09-08')
      earlier = make(start_date: '2016-08-18', end_date: '2016-08-25')

      expect(described_class.all.to_a).to eq([earlier, later])
    end
  end

  describe 'items' do
    let!(:axe)   { create(:item, display_name: 'Czekan', rentable_id: 20, cost: 10) }
    let!(:crampons) { create(:item, display_name: 'Raki', rentable_id: 31, cost: 15) }
    let(:reservation) { make.tap { |r| r.items << [axe, crampons] } }

    it '#cost sums the item costs' do
      expect(reservation.cost).to eq(25)
    end

    it '#items_display lists the name and the catalogue number' do
      expect(reservation.items_display).to contain_exactly('Czekan 20', 'Raki 31')
    end
  end

  describe 'presentation helpers' do
    subject(:reservation) { make(start_date: '2026-12-10', end_date: '2026-12-17') }

    it '#when shows the day range' do
      expect(reservation.when).to eq('10-17/12/2026')
    end

    it '#description names the borrower and their membership number' do
      expect(reservation.description).to eq(
        "Wypożyczenie sprzętu sportowego ##{reservation.id} przez #{user.display_name} o nr legitymacji klubowej: 4321"
      )
    end

    it '#payment_type is :reservations' do
      expect(reservation.payment_type).to eq(:reservations)
    end

    it 'delegates #kw_id to the user' do
      expect(reservation.kw_id).to eq(4321)
    end
  end
end
