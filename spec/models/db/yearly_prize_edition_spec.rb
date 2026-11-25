# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Db::YearlyPrizeEdition, type: :model do
  let(:now) { Time.utc(2026, 12, 12, 12, 0) }

  describe '.for_year' do
    it 'returns the edition of the given year' do
      edition = create(:yearly_prize_edition, year: 2026)
      create(:yearly_prize_edition, year: 2025)

      expect(described_class.for_year(2026)).to eq(edition)
    end

    it 'returns nil when there is no such edition' do
      expect(described_class.for_year(1999)).to be_nil
    end
  end

  describe '.create_with_categories' do
    it 'creates the edition with the three categories (Klubowa Ósemka is not a category)' do
      described_class.create_with_categories(2027)

      edition = described_class.for_year(2027)
      expect(edition.name).to eq('Klubowa Ósemka')
      expect(edition.yearly_prize_categories.order(:id).map(&:name)).to eq(['Ósemka STJ', 'Ósemka SNW', 'Ósemka SWW'])
    end
  end

  describe '#voting_started?' do
    it 'is false without a start date' do
      expect(build(:yearly_prize_edition).voting_started?(now)).to be(false)
    end

    it 'is false before the start date' do
      edition = build(:yearly_prize_edition, start_voting_date: now + 1.hour)

      expect(edition.voting_started?(now)).to be(false)
    end

    it 'is true from the start date on' do
      edition = build(:yearly_prize_edition, start_voting_date: now)

      expect(edition.voting_started?(now)).to be(true)
    end
  end

  describe '#finished?' do
    it 'is false for an open edition without an end date' do
      expect(build(:yearly_prize_edition).finished?(now)).to be(false)
    end

    it 'is false before the end date' do
      edition = build(:yearly_prize_edition, end_voting_date: now + 1.minute)

      expect(edition.finished?(now)).to be(false)
    end

    it 'is true after the end date' do
      edition = build(:yearly_prize_edition, end_voting_date: now - 1.minute)

      expect(edition.finished?(now)).to be(true)
    end

    it 'is true when the edition is closed, even before the end date' do
      edition = build(:yearly_prize_edition, closed: true, end_voting_date: now + 1.day)

      expect(edition.finished?(now)).to be(true)
    end
  end
end
