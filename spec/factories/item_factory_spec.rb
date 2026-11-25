# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'item factory' do
  it 'builds a rentable item by default' do
    expect(create(:item)).to be_rentable
  end

  it 'keeps the item rentable when a catalogue number is given' do
    item = create(:item, rentable_id: 20)

    expect(item.rentable_id).to eq(20)
    expect(item).to be_rentable
    expect(Db::Item.rentable).to include(item)
  end

  it 'still lets a spec make an item not rentable, with or without a catalogue number' do
    expect(create(:item, :not_rentable)).not_to be_rentable
    expect(create(:item, rentable: false, rentable_id: 21)).not_to be_rentable
  end

  it 'leaves the catalogue number empty by default' do
    expect(create(:item).rentable_id).to be_nil
  end
end
