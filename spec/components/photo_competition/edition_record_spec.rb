# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PhotoCompetition::EditionRecord, type: :model do
  let(:now) { Time.utc(2026, 12, 12, 12, 0) }

  describe '.for_year' do
    it 'finds the edition by its kasprzyk_<year> code' do
      edition = create(:photo_competition_edition, code: 'kasprzyk_2026')
      create(:photo_competition_edition, code: 'kasprzyk_2025')

      expect(described_class.for_year(2026)).to eq(edition)
    end

    it 'returns nil when there is no such edition' do
      expect(described_class.for_year(1999)).to be_nil
    end
  end

  describe '#voting_started?' do
    it 'is false without a start date' do
      expect(build(:photo_competition_edition).voting_started?(now)).to be(false)
    end

    it 'is false before and true from the start date' do
      expect(build(:photo_competition_edition, start_voting_date: now + 1.hour).voting_started?(now)).to be(false)
      expect(build(:photo_competition_edition, start_voting_date: now).voting_started?(now)).to be(true)
    end
  end

  describe '#finished?' do
    it 'is false for an open edition without an end date' do
      expect(build(:photo_competition_edition).finished?(now)).to be(false)
    end

    it 'is true after the end date' do
      expect(build(:photo_competition_edition, end_voting_date: now - 1.minute).finished?(now)).to be(true)
      expect(build(:photo_competition_edition, end_voting_date: now + 1.minute).finished?(now)).to be(false)
    end

    it 'is true when the edition is closed' do
      expect(build(:photo_competition_edition, closed: true, end_voting_date: now + 1.day).finished?(now)).to be(true)
    end
  end
end
