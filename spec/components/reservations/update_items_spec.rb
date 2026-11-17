# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Reservations::UpdateItems do
  subject(:service) { described_class.new(Reservations::UpdateItemsForm.new) }

  let(:reservation) { create(:reservation) }
  let!(:item_a) { create(:item, rentable_id: 101) }
  let!(:item_b) { create(:item, rentable_id: 102) }

  it 'replaces the items of the reservation' do
    result = service.call(raw_inputs: { id: reservation.id.to_s, items_ids: '101 102' })

    expect(result).to eq(Dry::Monads::Success(:success))
    expect(reservation.reload.items).to contain_exactly(item_a, item_b)
  end

  it 'fails when no item matches' do
    result = service.call(raw_inputs: { id: reservation.id.to_s, items_ids: '999' })

    expect(result).to eq(Dry::Monads::Failure(items: 'Rezerwacja musi mieć jakieś przedmioty!'))
  end

  it 'returns full Polish messages for blank input' do
    result = service.call(raw_inputs: { id: reservation.id.to_s, items_ids: '' })

    expect(result).to be_failure
    expect(result.failure[:items_ids]).to eq(['items_ids musi być wypełnione'])
  end

  it 'accepts ActionController::Parameters-like hashes with string keys' do
    result = service.call(raw_inputs: { 'id' => reservation.id.to_s, 'items_ids' => '101' })

    expect(result).to be_success
  end
end
