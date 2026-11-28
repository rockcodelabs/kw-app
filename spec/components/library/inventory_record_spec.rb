# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Library::InventoryRecord, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:checks) }
    it { is_expected.to have_many(:checked_items).through(:checks) }
  end

  describe 'state' do
    it 'defines in_progress and closed' do
      expect(described_class.states).to eq('in_progress' => 0, 'closed' => 1)
    end

    it 'starts in progress' do
      expect(described_class.new).to be_in_progress
    end
  end

  describe 'validations' do
    it 'requires a name' do
      round = build(:library_inventory, name: nil)

      expect(round).not_to be_valid
      expect(round.errors[:name]).to be_present
    end

    it 'sets started_at on create' do
      round = create(:library_inventory)

      expect(round.started_at).to be_within(5.seconds).of(Time.current)
    end

    it 'rejects a second round while one is in progress' do
      create(:library_inventory)
      second = build(:library_inventory)

      expect(second).not_to be_valid
      expect(second.errors[:base]).to be_present
    end

    it 'allows a new round after the previous one is closed' do
      create(:library_inventory, :closed)

      expect(build(:library_inventory)).to be_valid
    end

    it 'allows many closed rounds' do
      create(:library_inventory, :closed)

      expect(build(:library_inventory, :closed)).to be_valid
    end
  end

  describe '.current' do
    it 'returns the round in progress' do
      create(:library_inventory, :closed)
      round = create(:library_inventory)

      expect(described_class.current).to eq(round)
    end

    it 'is nil when no round is in progress' do
      create(:library_inventory, :closed)

      expect(described_class.current).to be_nil
    end
  end

  describe 'deleting a round' do
    it 'deletes its checks but keeps the items' do
      check = create(:library_inventory_check)

      expect { check.inventory.destroy }.to change(Library::InventoryCheckRecord, :count).by(-1)
      expect(Library::ItemRecord.exists?(check.item_id)).to be(true)
    end
  end
end
