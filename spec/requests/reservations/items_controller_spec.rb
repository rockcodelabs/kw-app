# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Reservations::ItemsController', type: :request do
  let(:admin) { create(:user, :admin) }
  let(:reservation) { create(:reservation) }
  let!(:item_a) { create(:item, rentable_id: 101) }
  let!(:item_b) { create(:item, rentable_id: 102) }

  describe 'PUT update' do
    before { sign_in admin }

    it 'replaces the reservation items' do
      put update_items_path(id: reservation.id), params: { reservation: { id: reservation.id, items_ids: '101 102' } }

      expect(response).to redirect_to(edit_admin_reservation_path(reservation.id.to_s))
      expect(reservation.reload.items).to contain_exactly(item_a, item_b)
    end

    it 'fails with a flash error when no items match' do
      put update_items_path(id: reservation.id), params: { reservation: { id: reservation.id, items_ids: '999' } }

      expect(response).to have_http_status(:redirect)
      expect(flash[:error]).to include('Rezerwacja musi mieć jakieś przedmioty!')
    end

    it 'fails with a flash error when items are blank' do
      put update_items_path(id: reservation.id), params: { reservation: { id: reservation.id, items_ids: '' } }

      expect(response).to have_http_status(:redirect)
      expect(flash[:error]).to include('musi być wypełnione')
      expect(reservation.reload.items).to be_empty
    end
  end
end
