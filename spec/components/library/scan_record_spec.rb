# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Library::ScanRecord, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:item) }
  end

  describe 'kind' do
    it 'defines cover, contents, map and other' do
      expect(described_class.kinds).to eq('cover' => 0, 'contents' => 1, 'map' => 2, 'other' => 3)
    end

    it 'defaults to other' do
      expect(described_class.new).to be_kind_other
    end
  end

  describe 'validations' do
    it 'requires an image' do
      scan = build(:library_scan, image: nil)

      expect(scan).not_to be_valid
      expect(scan.errors[:image]).to be_present
    end

    it 'accepts up to 5 scans per item' do
      item = create(:library_item)
      create_list(:library_scan, 4, item: item)

      expect(build(:library_scan, item: item)).to be_valid
    end

    it 'rejects the 6th scan of an item' do
      item = create(:library_item)
      create_list(:library_scan, 5, item: item)
      sixth = build(:library_scan, item: item)

      expect(sixth).not_to be_valid
      expect(sixth.errors[:base].first).to include('5')
    end

    it 'counts the limit per item' do
      create_list(:library_scan, 5, item: create(:library_item))

      expect(build(:library_scan, item: create(:library_item))).to be_valid
    end

    it 'allows only one cover per item' do
      item = create(:library_item)
      create(:library_scan, :cover, item: item)
      second_cover = build(:library_scan, :cover, item: item)

      expect(second_cover).not_to be_valid
      expect(second_cover.errors[:kind]).to be_present
    end

    it 'allows a cover on another item' do
      create(:library_scan, :cover)

      expect(build(:library_scan, :cover)).to be_valid
    end

    it 'still allows several non-cover scans of the same kind' do
      item = create(:library_item)
      create(:library_scan, kind: :map, item: item)

      expect(build(:library_scan, kind: :map, item: item)).to be_valid
    end
  end
end
