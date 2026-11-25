# frozen_string_literal: true

require 'rails_helper'

# Post-deploy critical flow: the gear reservation module (member side + admin side + payment).
RSpec.describe 'Reservations module', type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:member) { create(:user, :with_membership, :with_profile) }
  let(:other_member) { create(:user, :with_membership, :with_profile) }
  let(:keeper) { create(:user, :with_reservations_role, :with_membership, :with_profile) }

  let(:start_date) { Date.current.next_occurring(:thursday) }
  let(:end_date) { start_date.next_week(:thursday) }
  let!(:item) { create(:item) }
  let!(:other_item) { create(:item) }

  before { ActiveJob::Base.queue_adapter = :test }

  describe 'member side' do
    it 'sends anonymous visitors to the login page' do
      get reservations_path(start_date: start_date.to_s)

      expect(response).to have_http_status(:redirect)
    end

    context 'when signed in' do
      before { sign_in member }

      it 'redirects to the nearest Thursday when the date is not a Thursday' do
        get reservations_path(start_date: (start_date + 1.day).to_s)

        expect(response).to have_http_status(:redirect)
      end

      it 'shows the availability for a Thursday' do
        get reservations_path(start_date: start_date.to_s)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(item.display_name)
      end

      it 'refuses a date in the past' do
        get reservations_path(start_date: Date.current.prev_occurring(:thursday).to_s)

        expect(response).to have_http_status(:redirect)
        expect(flash[:alert]).to eq('Data nie może być w przeszłości')
      end

      it 'redirects the availability form back to the list for the chosen week' do
        post availability_reservations_path, params: { availability_form: { start_date: start_date.to_s } }

        expect(response).to redirect_to(reservations_path(start_date: start_date.to_s))
      end

      it 'reserves an item and creates an unpaid payment' do
        expect do
          post reservations_path, params: { reservations_form: { start_date: start_date.to_s, end_date: end_date.to_s, item_ids: [item.id.to_s] } }
        end.to change(Db::Reservation, :count).by(1).and change(Db::Payment, :count).by(1)

        reservation = Db::Reservation.last
        expect(reservation.user).to eq(member)
        expect(reservation.items).to contain_exactly(item)
        expect(reservation.payment.state).to eq('unpaid')
        expect(reservation.payment.dotpay_id).to be_present
        expect(flash[:notice]).to eq('Zarezerwowano przedmiot.')
      end

      it 'adds a second item to the same unpaid reservation for the same week' do
        2.times do |i|
          post reservations_path, params: { reservations_form: { start_date: start_date.to_s, end_date: end_date.to_s, item_ids: [[item, other_item][i].id.to_s] } }
        end

        expect(Db::Reservation.where(user_id: member.id).count).to eq(1)
        expect(Db::Reservation.last.items).to contain_exactly(item, other_item)
      end

      it 'refuses an item that somebody else already reserved for that week' do
        create(:reservation, start_date: start_date, end_date: end_date, user: other_member).items << item

        expect do
          post reservations_path, params: { reservations_form: { start_date: start_date.to_s, end_date: end_date.to_s, item_ids: [item.id.to_s] } }
        end.not_to change(Db::Reservation, :count)

        expect(flash[:alert]).to eq('Przedmiot został już zarezerwowany w tym okresie.')
      end

      it 'refuses an invalid week (end date not one week after the start)' do
        expect do
          post reservations_path, params: { reservations_form: { start_date: start_date.to_s, end_date: (end_date + 7.days).to_s, item_ids: [item.id.to_s] } }
        end.not_to change(Db::Reservation, :count)

        expect(flash[:alert]).to start_with('Nie dodano z powodu')
      end

      it 'cancels an item and removes the empty unpaid reservation with its payment' do
        post reservations_path, params: { reservations_form: { start_date: start_date.to_s, end_date: end_date.to_s, item_ids: [item.id.to_s] } }
        reservation = Db::Reservation.last

        expect { delete delete_item_reservation_path(reservation), params: { item_id: item.id } }
          .to change(Db::Reservation, :count).by(-1).and change(Db::Payment, :count).by(-1)

        expect(flash[:notice]).to eq('Zrezygnowano z rezerwacji przedmiotu.')
      end

      it "does not let a member cancel another member's reservation item" do
        reservation = create(:reservation, start_date: start_date, end_date: end_date, user: other_member)
        reservation.items << item
        reservation.create_payment(dotpay_id: SecureRandom.hex(13))

        delete delete_item_reservation_path(reservation), params: { item_id: item.id }

        expect(reservation.reload.items).to contain_exactly(item)
      end

      it 'lets the keeper (reservations role) cancel an item of somebody else\'s reservation' do
        reservation = create(:reservation, start_date: start_date, end_date: end_date, user: other_member)
        reservation.items << [item, other_item]
        reservation.create_payment(dotpay_id: SecureRandom.hex(13))
        sign_in keeper

        delete delete_item_reservation_path(reservation), params: { item_id: item.id }

        expect(reservation.reload.items).to contain_exactly(other_item)
      end
    end
  end

  describe 'admin side' do
    let!(:reservation) do
      create(:reservation, start_date: start_date, end_date: end_date, user: member).tap do |r|
        r.items << item
        r.create_payment(dotpay_id: SecureRandom.hex(13))
      end
    end

    context 'with the reservations role' do
      before { sign_in keeper }

      it 'lists reservations and renders the edit form' do
        get admin_reservations_path
        expect(response).to have_http_status(:ok)

        get edit_admin_reservation_path(reservation)
        expect(response).to have_http_status(:ok)
      end

      it 'exports the list as xlsx' do
        get admin_reservations_path(format: :xlsx)

        expect(response).to have_http_status(:ok)
      end

      it 'marks the reservation as given' do
        put give_admin_reservation_path(reservation)

        expect(response).to redirect_to(admin_reservations_path)
        expect(reservation.reload.state).not_to eq('reserved')
      end

      it 'archives the reservation' do
        put archive_admin_reservation_path(reservation)

        expect(reservation.reload.state).to eq('archived')
      end

      it 'offers the "Oddane" action for a given out reservation and marks it as returned' do
        reservation.give!

        get admin_reservations_path
        expect(response.body).to include('Oddane')
        expect(response.body).not_to include('Zarchiwizuj')

        get edit_admin_reservation_path(reservation)
        expect(response.body).to include('Oddane')

        put archive_admin_reservation_path(reservation)
        expect(flash[:notice]).to eq('Oznaczono jako oddane')
        expect(reservation.reload.state).to eq('archived')
      end

      it 'marks the payment as paid in cash' do
        put charge_admin_reservation_path(reservation)

        expect(reservation.payment.reload.cash).to be(true)
      end

      it 'sends a reminder mail' do
        expect { post remind_admin_reservation_path(reservation) }
          .to have_enqueued_mail(ReservationMailer, :remind)
      end

      it 'adds and removes a warning' do
        expect { post give_warning_admin_reservation_path(reservation) }
          .to change { member.reload.warnings }.by(1)
        expect { post give_back_warning_admin_reservation_path(reservation) }
          .to change { member.reload.warnings }.by(-1)
      end

      it 'destroys the reservation' do
        expect { delete admin_reservation_path(reservation) }
          .to change(Db::Reservation, :count).by(-1)
      end
    end

    context 'without the reservations role' do
      before { sign_in member }

      it 'does not give, archive or destroy' do
        put give_admin_reservation_path(reservation)
        put archive_admin_reservation_path(reservation)
        expect { delete admin_reservation_path(reservation) }.not_to change(Db::Reservation, :count)

        expect(reservation.reload.state).to eq('reserved')
      end
    end
  end

  describe 'the unpaid-reservation cleanup (cron destroy_unpaid_reservations)' do
    let!(:unpaid) { create(:reservation, user: member, created_at: 3.days.ago).tap { |r| r.create_payment(dotpay_id: SecureRandom.hex(13)) } }
    let!(:cash_paid) do
      create(:reservation, user: other_member, created_at: 3.days.ago).tap do |r|
        r.create_payment(dotpay_id: SecureRandom.hex(13), cash: true, state: 'prepaid')
      end
    end
    let!(:fresh) { create(:reservation, user: keeper).tap { |r| r.create_payment(dotpay_id: SecureRandom.hex(13)) } }

    it 'destroys only old unpaid reservations and keeps cash-paid and fresh ones' do
      Reservations::Unpaid.new.destroy_all

      expect(Db::Reservation.exists?(unpaid.id)).to be(false)
      expect(Db::Reservation.exists?(cash_paid.id)).to be(true)
      expect(Db::Reservation.exists?(fresh.id)).to be(true)
    end

    it 'lists the same reservations as candidates for the worker dry run' do
      expect(Reservations::Workers::DestroyUnpaidReservationsWorker.candidates.map(&:id)).to include(unpaid.id)
    end
  end
end
