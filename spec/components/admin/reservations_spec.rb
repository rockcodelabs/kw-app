# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::Reservations do
  let!(:member) { create(:user, kw_id: 7777) }
  let!(:item) { create(:item) }

  def params(overrides = {})
    { kw_id: '7777', start_date: '2026-12-10', end_date: '2026-12-17', remarks: 'z kasy' }.merge(overrides)
  end

  describe '#create' do
    it 'creates a reservation for the member with the given kw_id' do
      result = nil
      expect { result = described_class.new(params).create }.to change(Db::Reservation, :count).by(1)

      reservation = Db::Reservation.last
      expect(result.success?).to eq(true)
      expect(reservation.user).to eq(member)
      expect(reservation.start_date).to eq(Date.new(2026, 12, 10))
      expect(reservation.end_date).to eq(Date.new(2026, 12, 17))
      expect(reservation.remarks).to eq('z kasy')
      expect(reservation).to be_reserved
    end

    it 'fails with the form when kw_id is blank' do
      result = nil
      expect { result = described_class.new(params(kw_id: '')).create }.not_to change(Db::Reservation, :count)

      expect(result.invalid?).to eq(true)
    end

    it 'fails with a message (instead of crashing) when no member has that kw_id' do
      result = nil
      expect { result = described_class.new(params(kw_id: '99999')).create }.not_to change(Db::Reservation, :count)

      expect(result.invalid?).to eq(true)
      messages = nil
      result.invalid { |form:| messages = form.errors[:kw_id] }
      expect(messages).to include('nie ma klubowicza o takim numerze')
    end
  end

  describe '#update' do
    let!(:reservation) { create(:reservation, user: member, start_date: '2026-12-10', end_date: '2026-12-17') }

    it 'changes the dates and remarks' do
      result = described_class.new(params(start_date: '2026-12-17', end_date: '2026-12-24', remarks: 'przesunięte'))
                              .update(reservation.id)

      reservation.reload
      expect(result.success?).to eq(true)
      expect(reservation.start_date).to eq(Date.new(2026, 12, 17))
      expect(reservation.end_date).to eq(Date.new(2026, 12, 24))
      expect(reservation.remarks).to eq('przesunięte')
    end

    it 'does not change the state' do
      reservation.give!

      described_class.new(params(remarks: 'nowa uwaga')).update(reservation.id)

      expect(reservation.reload).to be_holding
    end

    it 'fails when kw_id is blank and leaves the reservation untouched' do
      result = described_class.new(params(kw_id: '', remarks: 'nope')).update(reservation.id)

      expect(result.invalid?).to eq(true)
      expect(reservation.reload.remarks).not_to eq('nope')
    end
  end

  describe '.destroy' do
    it 'removes the reservation' do
      reservation = create(:reservation, user: member)

      result = nil
      expect { result = described_class.destroy(reservation.id) }.to change(Db::Reservation, :count).by(-1)

      expect(result.success?).to eq(true)
    end

    it 'raises for an unknown id' do
      expect { described_class.destroy(0) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
