require 'rails_helper'

describe Reservations::CreateReservation do
  let!(:user) { create(:user) }
  let!(:item) { create(:item) }

  before { Timecop.freeze('2016-08-14'.to_date) }
  after { Timecop.return }

  context 'start_date is not thursday' do
    it 'fails' do
      form = build(:reservation_form, start_date: '2016-10-10')
      result = Reservations::CreateReservation.create(form: form, user: user)

      expect(result.form_invalid?).to eq(true)
    end
  end

  context 'start_date is in the past' do
    it 'fails' do
      form = build(:reservation_form, start_date: '2016-08-04')
      result = Reservations::CreateReservation.create(form: form, user: user)

      expect(result.form_invalid?).to eq(true)
    end
  end
  
  context 'end_date is not thursday' do
    it 'fails' do
      form = build(:reservation_form, end_date: '2016-09-10')
      result = Reservations::CreateReservation.create(form: form, user: user)

      expect(result.form_invalid?).to eq(true)
    end
  end

  context 'end_date is before start_date' do
    it 'fails' do
      form = build(:reservation_form, start_date: '2016-09-15', end_date: '2016-09-08')
      result = Reservations::CreateReservation.create(form: form, user: user)

      expect(result.form_invalid?).to eq(true)
    end
  end

  context 'end_date is not one week later' do
    it 'fails' do
      form = build(:reservation_form, start_date: '2016-08-18', end_date: '2016-09-08')
      result = Reservations::CreateReservation.create(form: form, user: user)

      expect(result.form_invalid?).to eq(true)
    end
  end

  it 'has to be at least one item' do
    form = build(:reservation_form, item_ids: [])
    result = Reservations::CreateReservation.create(form: form, user: user)

    expect(result.form_invalid?).to eq(true)
  end

  context 'other person reserved item in this time' do
    before do
      reservation = create(:reservation)
      reservation.items << item
    end

    it 'fails' do
      form = build(:reservation_form, item_ids: [item.id])
      result = Reservations::CreateReservation.create(form: form, user: user)

      expect(result.item_already_reserved?).to eq(true)
    end
  end

  context 'item given out earlier and not returned yet' do
    let!(:holder) { create(:user) }
    let!(:held_reservation) do
      create(:reservation, user: holder, state: 'holding', start_date: '2016-08-11', end_date: '2016-08-18')
        .tap { |r| r.items << item }
    end

    it 'fails' do
      form = build(:reservation_form, item_ids: [item.id])
      result = Reservations::CreateReservation.create(form: form, user: user)

      expect(result.item_already_reserved?).to eq(true)
      expect(Db::Reservation.count).to eq(1)
    end

    it 'succeeds after the item is marked as returned' do
      held_reservation.archive!
      form = build(:reservation_form, item_ids: [item.id])
      result = Reservations::CreateReservation.create(form: form, user: user)

      expect(result.success?).to eq(true)
    end
  end

  context 'start_date is thursday in the future' do
    it 'creates reservation successfully' do
      form = build(:reservation_form, item_ids: [item.id])

      result = Reservations::CreateReservation.create(form: form, user: user)

      expect(Db::Reservation.count).to eq(1)
      expect(Db::Payment.count).to eq(1)
      expect(result.success?).to eq(true)

      reservation = Db::Reservation.first
      expect(reservation.start_date).to eq('2016-08-18'.to_date)
      expect(reservation.end_date).to eq('2016-08-25'.to_date)
      expect(reservation.items).to match_array([item])
      expect(reservation.user).to eq(user)
      expect(reservation.reserved?).to eq(true)
      expect(reservation.payment).to be_present
      expect(reservation.payment.unpaid?).to eq(true)
    end
  end

  context 'reservation has already been prepaid in this period' do
    it 'creates another reservation' do
      item2 = create(:item)
      reservation = create(:reservation, start_date: '2016-08-18', end_date: '2016-08-25', user: user)
      reservation.items << item
      payment = reservation.create_payment(dotpay_id: SecureRandom.hex(13), state: 'unpaid')
      payment.charge!
      
      form = build(:reservation_form, item_ids: [item2.id])

      result = nil
      expect do
        result = Reservations::CreateReservation.create(form: form, user: user)
      end.to change(Db::Reservation, :count).from(1).to(2)
      
      expect(result.success?).to eq(true)
    end
  end
end
