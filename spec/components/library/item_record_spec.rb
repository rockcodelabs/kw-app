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

  describe 'new associations' do
    it { is_expected.to have_many(:scans) }
    it { is_expected.to have_many(:inventory_checks) }

    it 'returns scans ordered by position' do
      item = create(:library_item)
      second = create(:library_scan, item: item, position: 2)
      first = create(:library_scan, item: item, position: 1)

      expect(item.scans).to eq([first, second])
    end

    it 'deletes scans and checks together with the item' do
      item = create(:library_item)
      create(:library_scan, item: item)
      create(:library_inventory_check, item: item)

      expect { item.destroy }
        .to change(Library::ScanRecord, :count).by(-1)
        .and change(Library::InventoryCheckRecord, :count).by(-1)
    end
  end

  describe 'catalog defaults' do
    subject(:item) { described_class.new }

    it { expect(item.disciplines).to eq([]) }
    it { expect(item.countries).to eq([]) }
    it { expect(item.reading_room).to be(false) }
  end

  describe 'validations' do
    it 'requires a title' do
      item = build(:library_item, title: nil)

      expect(item).not_to be_valid
      expect(item.errors[:title]).to be_present
    end

    it 'accepts disciplines and countries from the catalog' do
      item = build(:library_item, :guide, disciplines: %w[wspinaczkowy skiturowy], countries: %w[Polska Słowacja])

      expect(item).to be_valid
    end

    it 'rejects a discipline outside the catalog' do
      item = build(:library_item, disciplines: ['wspinaczkowy', 'curling'])

      expect(item).not_to be_valid
      expect(item.errors[:disciplines].first).to include('curling')
    end

    it 'rejects a country outside the catalog' do
      item = build(:library_item, countries: ['Spain'])

      expect(item).not_to be_valid
      expect(item.errors[:countries].first).to include('Spain')
    end

    it 'drops blank values submitted by multi-selects' do
      item = build(:library_item, disciplines: ['', 'skiturowy'], countries: [''])

      expect(item).to be_valid
      expect(item.disciplines).to eq(['skiturowy'])
      expect(item.countries).to eq([])
    end

    it 'persists the arrays' do
      item = create(:library_item, disciplines: %w[trekkingowy], countries: %w[Nepal])

      expect(item.reload).to have_attributes(disciplines: %w[trekkingowy], countries: %w[Nepal])
    end
  end

  describe '.duplicated_numbers' do
    it 'returns every item that shares its number with another item' do
      first = create(:library_item, item_id: 302)
      second = create(:library_item, item_id: 302)
      create(:library_item, item_id: 303)

      expect(described_class.duplicated_numbers).to contain_exactly(first, second)
    end

    it 'ignores items without a number' do
      create_list(:library_item, 2, item_id: nil)

      expect(described_class.duplicated_numbers).to be_empty
    end

    it 'is empty when every number is unique' do
      create(:library_item, item_id: 1)
      create(:library_item, item_id: 2)

      expect(described_class.duplicated_numbers).to be_empty
    end
  end

  describe '.next_number' do
    it 'is 1 when the library is empty' do
      expect(described_class.next_number).to eq(1)
    end

    it 'is the highest number plus one' do
      create(:library_item, item_id: 10)
      create(:library_item, item_id: 1134)

      expect(described_class.next_number).to eq(1135)
    end
  end
end
