# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PhotoCompetition::RequestRecord do
  let(:user) { create(:user) }
  let(:edition) { PhotoCompetition::EditionRecord.create!(code: 'kasprzyk_test', name: 'Edycja testowa') }
  let(:category) { edition.categories.create!(name: 'Kat. „A” – wspinaczka skałkowa', mandatory_fields: %w[title area]) }
  let(:other_category) { edition.categories.create!(name: 'Kat. „F” - Akcja', mandatory_fields: []) }

  def build_request(owner: user, in_category: category, in_edition: edition)
    described_class.new(user: owner, edition: in_edition, category: in_category, title: 'Tytuł', area: 'Rejon')
  end

  def store_without_validation(count, **options)
    count.times { build_request(**options).save!(validate: false) }
  end

  describe 'photos per category limit' do
    it 'is 5' do
      expect(described_class::MAX_PHOTOS_PER_CATEGORY).to eq(5)
    end

    it 'allows the 5th photo in a category' do
      store_without_validation(4)

      request = build_request
      request.valid?

      expect(request.errors[:base]).to be_empty
    end

    it 'rejects the 6th photo in the same category' do
      store_without_validation(5)

      request = build_request
      request.valid?

      expect(request.errors[:base]).to include('Możesz zgłosić maksymalnie 5 zdjęć w jednej kategorii')
    end

    it 'counts each category separately' do
      store_without_validation(5)

      request = build_request(in_category: other_category)
      request.valid?

      expect(request.errors[:base]).to be_empty
    end

    it 'counts each user separately' do
      store_without_validation(5)

      request = build_request(owner: create(:user))
      request.valid?

      expect(request.errors[:base]).to be_empty
    end

    it 'counts each edition separately' do
      store_without_validation(5)
      next_edition = PhotoCompetition::EditionRecord.create!(code: 'kasprzyk_next', name: 'Następna edycja')
      next_category = next_edition.categories.create!(name: 'Kat. „A” – wspinaczka skałkowa', mandatory_fields: [])

      request = build_request(in_category: next_category, in_edition: next_edition)
      request.valid?

      expect(request.errors[:base]).to be_empty
    end

    it 'does not block updating an already stored photo' do
      store_without_validation(6)

      stored = described_class.first
      stored.accepted = true
      stored.valid?

      expect(stored.errors[:base]).to be_empty
    end
  end
end
