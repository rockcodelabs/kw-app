# frozen_string_literal: true

require 'rails_helper'

# An item that was given out (holding) and not marked as returned ("Oddane") must stay unavailable
# for every following week, both in the public list and when somebody tries to book it.
RSpec.describe 'Reservations: items that were not returned', type: :request do
  let(:holder) { create(:user, :with_membership, :with_profile) }
  let(:next_member) { create(:user, :with_membership, :with_profile) }
  let(:keeper) { create(:user, :with_reservations_role, :with_membership, :with_profile) }

  let(:first_week) { Date.current.next_occurring(:thursday) }
  let(:second_week) { first_week + 7.days }
  let(:third_week) { first_week + 14.days }

  let!(:axe) { create(:item, display_name: 'Czekan Testowy Alfa') }
  let!(:other_axe) { create(:item, display_name: 'Czekan Testowy Beta') }

  let!(:held) do
    create(:reservation, user: holder, start_date: first_week, end_date: second_week).tap do |r|
      r.items << axe
      r.create_payment(dotpay_id: SecureRandom.hex(13)).charge!
    end
  end

  before { ActiveJob::Base.queue_adapter = :test }

  def book(item, from:, to:)
    post reservations_path, params: { reservations_form: { start_date: from.to_s, end_date: to.to_s, item_ids: [item.id.to_s] } }
  end

  describe 'public availability list' do
    before { sign_in next_member }

    it 'offers the item in the following week while it is only reserved (not handed over)' do
      get reservations_path(start_date: second_week.to_s)

      expect(response.body).to include('Czekan Testowy Alfa')
    end

    it 'hides the item in the following weeks once it was handed over' do
      held.give!

      [second_week, third_week].each do |week|
        get reservations_path(start_date: week.to_s)

        expect(response.body).not_to include('Czekan Testowy Alfa')
        expect(response.body).to include('Czekan Testowy Beta')
      end
    end

    it 'offers the item again once it was marked as returned' do
      held.give!
      held.archive!

      get reservations_path(start_date: second_week.to_s)

      expect(response.body).to include('Czekan Testowy Alfa')
    end
  end

  describe 'booking' do
    before { sign_in next_member }

    it 'refuses to book an item that is still out' do
      held.give!

      expect { book(axe, from: second_week, to: third_week) }.not_to change(Db::Reservation, :count)

      expect(flash[:alert]).to eq('Przedmiot został już zarezerwowany w tym okresie.')
    end

    it 'still lets the member book another item' do
      held.give!

      expect { book(other_axe, from: second_week, to: third_week) }.to change(Db::Reservation, :count).by(1)
    end

    it 'allows booking after the keeper marks the item as returned' do
      held.give!
      sign_in keeper
      put archive_admin_reservation_path(held)
      expect(flash[:notice]).to eq('Oznaczono jako oddane')

      sign_in next_member
      expect { book(axe, from: second_week, to: third_week) }.to change(Db::Reservation, :count).by(1)
      expect(Db::Reservation.last.items).to contain_exactly(axe)
    end
  end

  describe 'admin list' do
    let!(:handed_over) do
      create(:reservation, user: next_member, start_date: first_week, end_date: second_week, state: 'holding')
        .tap { |r| r.items << other_axe }
    end
    let!(:returned) do
      create(:reservation, user: next_member, start_date: first_week - 14.days, end_date: first_week - 7.days, state: 'archived')
    end

    before { sign_in keeper }

    it 'shows active reservations with the right status labels and actions' do
      get admin_reservations_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('zarezerwowano')
      expect(response.body).to include('w posiadaniu')
      expect(response.body).to include('Oddane')
      expect(response.body).to include('Przekaż')
      expect(response.body).to include('Przypomnij')
      expect(response.body).not_to include('Zarchiwizuj')
      expect(response.body).not_to include(admin_reservation_path(returned))
    end

    it 'offers the "Oddane" action only for handed over reservations' do
      get admin_reservations_path

      expect(response.body).to include(archive_admin_reservation_path(handed_over))
      expect(response.body).not_to include(archive_admin_reservation_path(held))
    end

    it 'lists only the returned reservations under "Pokaż tylko oddane"' do
      get admin_reservations_path

      expect(response.body).to include('Pokaż tylko oddane')

      get admin_reservations_path(archived: true)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('oddane')
      expect(response.body).to include('Pokaż tylko aktywne')
      expect(response.body).to include(edit_admin_reservation_path(returned))
      expect(response.body).not_to include(edit_admin_reservation_path(handed_over))
      expect(response.body).not_to include(edit_admin_reservation_path(held))
    end

    it 'marks the reservation as returned from the list and frees the item' do
      put archive_admin_reservation_path(handed_over)

      expect(response).to redirect_to(admin_reservations_path)
      expect(handed_over.reload).to be_archived
      expect(Availability::Items.new(start_date: second_week).collect).to include(other_axe)
    end

    it 'shows the "Oddane" button on the edit page of a handed over reservation only' do
      get edit_admin_reservation_path(handed_over)
      expect(response.body).to include(archive_admin_reservation_path(handed_over))

      get edit_admin_reservation_path(held)
      expect(response.body).not_to include(archive_admin_reservation_path(held))
    end

    it 'cannot mark a reservation as returned twice' do
      put archive_admin_reservation_path(returned)

      expect(response).to redirect_to(admin_reservations_path)
      expect(flash[:alert]).to eq('Rezerwacja jest już oddana')
      expect(returned.reload).to be_archived
    end

    it 'cannot hand over a returned reservation again' do
      put give_admin_reservation_path(returned)

      expect(response).to redirect_to(admin_reservations_path)
      expect(flash[:alert]).to eq('Rezerwacja jest już przekazana lub oddana')
      expect(returned.reload).to be_archived
    end

    it 'cannot hand over an already handed over reservation (double click)' do
      put give_admin_reservation_path(handed_over)

      expect(response).to redirect_to(admin_reservations_path)
      expect(flash[:alert]).to eq('Rezerwacja jest już przekazana lub oddana')
      expect(handed_over.reload).to be_holding
    end
  end

  describe 'a member without the reservations role' do
    before { sign_in next_member }

    it 'cannot mark somebody else\'s reservation as returned' do
      held.give!

      put archive_admin_reservation_path(held)

      expect(held.reload).to be_holding
      expect(Availability::Items.new(start_date: second_week).collect).not_to include(axe)
    end
  end
end
