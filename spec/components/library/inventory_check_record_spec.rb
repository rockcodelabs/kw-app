# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Library::InventoryCheckRecord, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:inventory) }
    it { is_expected.to belong_to(:item) }
  end

  describe 'validations' do
    it 'is valid from the factory' do
      expect(build(:library_inventory_check)).to be_valid
    end

    it 'sets checked_at when it is blank' do
      check = create(:library_inventory_check)

      expect(check.checked_at).to be_within(5.seconds).of(Time.current)
    end

    it 'keeps a given checked_at' do
      time = Time.zone.local(2026, 11, 28, 10, 0)

      expect(create(:library_inventory_check, checked_at: time).checked_at).to eq(time)
    end

    it 'allows an item only once per round' do
      check = create(:library_inventory_check)
      duplicate = build(:library_inventory_check, inventory: check.inventory, item: check.item)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:item_id]).to be_present
    end

    it 'allows the same item in another round' do
      check = create(:library_inventory_check)
      check.inventory.closed!
      other_round = create(:library_inventory)

      expect(build(:library_inventory_check, inventory: other_round, item: check.item)).to be_valid
    end
  end
end
