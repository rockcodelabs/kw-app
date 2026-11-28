# frozen_string_literal: true

require 'rails_helper'

# Baseline (characterization) spec: pins the behaviour of the library item model
# as it is today, so the inventory migration and model changes can be done safely.
RSpec.describe Library::ItemRecord, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:item_authors) }
    it { is_expected.to have_many(:authors).through(:item_authors) }
    it { is_expected.to have_many(:library_item_reservations) }
    it { is_expected.to have_many(:library_reservators).through(:library_item_reservations) }
    it { is_expected.to have_many(:item_tags) }
    it { is_expected.to have_many(:tags).through(:item_tags) }
  end

  describe 'factory' do
    it 'creates a valid record' do
      expect(create(:library_item)).to be_persisted
    end
  end

  describe 'doc_type' do
    it 'defines book, magazine and guide' do
      expect(described_class.doc_types).to eq('book' => 0, 'magazine' => 1, 'guide' => 2)
    end

    it 'is a guide for the guide trait' do
      expect(create(:library_item, :guide)).to be_guide
    end
  end

  describe 'slug' do
    it 'is generated from the title' do
      item = create(:library_item, title: 'Tatry Wysokie')

      expect(item.slug).to eq('tatry-wysokie')
    end

    it 'stays unique for items with the same title' do
      first = create(:library_item, title: 'Tatry Wysokie')
      second = create(:library_item, title: 'Tatry Wysokie')

      expect(second.slug).not_to eq(first.slug)
    end

    it 'finds the record by slug' do
      item = create(:library_item, title: 'Dolomity')

      expect(described_class.friendly.find('dolomity')).to eq(item)
    end
  end

  describe '#item_id (library number)' do
    it 'is not unique today, duplicates are allowed' do
      create(:library_item, item_id: 302)

      expect(build(:library_item, item_id: 302)).to be_valid
    end
  end

  describe '#on_place?' do
    let(:item) { create(:library_item) }

    it 'is true when there are no reservations' do
      expect(item).to be_on_place
    end

    it 'is false when a reservation is still open' do
      create(:library_item_reservation, item: item, back_at: nil)

      expect(item).not_to be_on_place
    end

    it 'is true when every reservation was returned' do
      create(:library_item_reservation, item: item, back_at: Date.current)

      expect(item).to be_on_place
    end
  end

  describe '#authors_names=' do
    it 'assigns authors by ids' do
      author = create(:library_author)
      item = create(:library_item)

      item.authors_names = [author.id]
      item.save!

      expect(item.reload.authors).to contain_exactly(author)
    end
  end

  describe 'tags' do
    it 'links tags through item_tags' do
      tag = create(:library_tag)
      item = create(:library_item)

      item.tags << tag

      expect(item.reload.tags).to contain_exactly(tag)
    end
  end
end
