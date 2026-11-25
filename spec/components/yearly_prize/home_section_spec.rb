# frozen_string_literal: true

require 'rails_helper'

RSpec.describe YearlyPrize::HomeSection do
  let(:user) { create(:user) }
  let(:start_at) { Time.utc(2026, 12, 11, 6, 0) }
  let(:end_at) { Time.utc(2026, 12, 15, 22, 59) }
  let(:now) { Time.utc(2026, 12, 12, 12, 0) }
  let!(:edition) { create(:yearly_prize_edition, year: 2026, start_voting_date: start_at, end_voting_date: end_at) }
  let!(:category_a) { create(:yearly_prize_category, yearly_prize_edition: edition, name: 'Ósemka STJ') }
  let!(:category_b) { create(:yearly_prize_category, yearly_prize_edition: edition, name: 'Ósemka SNW') }

  subject(:section) { described_class.new(user: user, now: now) }

  def nomination(category:, likes: 0, **attrs)
    create(:yearly_prize_request, yearly_prize_edition: edition, yearly_prize_category: category, **attrs).tap do |request|
      likes.times { create(:like, likeable: request) }
    end
  end

  describe '#stage' do
    it 'is hidden when there is no edition for the current year' do
      edition.update!(year: 2025)

      expect(section.stage).to eq(:hidden)
      expect(section.visible?).to be(false)
    end

    it 'is hidden from 1 January (Warsaw time) even though the old edition has results' do
      section = described_class.new(user: user, now: Time.utc(2026, 12, 31, 23, 0))

      expect(section.stage).to eq(:hidden)
    end

    it 'still shows results on the last evening of the year (Warsaw time)' do
      section = described_class.new(user: user, now: Time.utc(2026, 12, 31, 22, 59))

      expect(section.stage).to eq(:results)
    end

    it 'is submissions before voting starts' do
      section = described_class.new(user: user, now: start_at - 1.day)

      expect(section.stage).to eq(:submissions)
    end

    it 'is submissions when the edition has no start date yet' do
      edition.update!(start_voting_date: nil)

      expect(section.stage).to eq(:submissions)
    end

    it 'is voting while voting is open and the user has not voted' do
      expect(section.stage).to eq(:voting)
      expect(section.my_vote).to be_nil
    end

    it 'is voted once the user cast a vote in this edition' do
      request = nomination(category: category_a)
      create(:like, user: user, likeable: request)

      expect(section.stage).to eq(:voted)
      expect(section.my_vote).to eq(request)
    end

    it 'ignores votes of other users' do
      create(:like, likeable: nomination(category: category_a))

      expect(section.stage).to eq(:voting)
    end

    it 'ignores votes cast in other editions' do
      other = create(:yearly_prize_request)
      create(:like, user: user, likeable: other)

      expect(section.stage).to eq(:voting)
    end

    it 'is results after the voting end date' do
      section = described_class.new(user: user, now: end_at + 1.minute)

      expect(section.stage).to eq(:results)
    end

    it 'is results when the edition is closed, even within the voting window' do
      edition.update!(closed: true)

      expect(section.stage).to eq(:results)
    end

    it 'is results (not voted) for a user who voted once the edition is finished' do
      create(:like, user: user, likeable: nomination(category: category_a))
      section = described_class.new(user: user, now: end_at + 1.minute)

      expect(section.stage).to eq(:results)
    end
  end

  describe '#categories' do
    it 'groups nominations by category, skipping empty categories' do
      first = nomination(category: category_a)
      second = nomination(category: category_a)

      groups = section.categories

      expect(groups.map { |group| group.category.name }).to eq(['Ósemka STJ'])
      expect(groups.first.requests).to eq([first, second])
    end

    it 'does not include nominations of other editions' do
      create(:yearly_prize_request)

      expect(section.categories).to be_empty
    end
  end

  describe '#results' do
    it 'ranks nominations by vote count within each category' do
      low = nomination(category: category_a, likes: 1)
      high = nomination(category: category_a, likes: 3)
      other = nomination(category: category_b, likes: 2)
      edition.update!(closed: true)

      results = section.results

      expect(results.map { |group| group.category.name }).to eq(['Ósemka STJ', 'Ósemka SNW'])
      expect(results.first.entries.map(&:request)).to eq([high, low])
      expect(results.first.entries.map(&:rank)).to eq([1, 2])
      expect(results.last.entries.map(&:request)).to eq([other])
    end

    it 'gives tied nominations the same rank' do
      nomination(category: category_a, likes: 2)
      nomination(category: category_a, likes: 2)
      nomination(category: category_a, likes: 1)
      edition.update!(closed: true)

      expect(section.results.first.entries.map(&:rank)).to eq([1, 1, 3])
    end
  end

  describe '#summary' do
    it 'prefers the jury description and truncates it to 200 characters' do
      request = nomination(category: category_a, author_description: 'autor', prize_jury_description: 'a' * 300)

      expect(section.summary(request).length).to eq(200)
      expect(section.summary(request)).to start_with('aaa')
    end

    it 'falls back to the author description' do
      request = nomination(category: category_a, author_description: 'Opis autora', prize_jury_description: '')

      expect(section.summary(request)).to eq('Opis autora')
    end

    it 'strips html so the card stays plain text' do
      request = nomination(category: category_a, author_description: '<b>Opis</b> autora')

      expect(section.summary(request)).to eq('Opis autora')
    end
  end

  describe '#votes_label' do
    it 'uses the Polish plural forms' do
      labels = [0, 1, 2, 4, 5, 12, 22, 25].map { |count| section.votes_label(count) }

      expect(labels).to eq(['0 głosów', '1 głos', '2 głosy', '4 głosy', '5 głosów', '12 głosów', '22 głosy', '25 głosów'])
    end
  end

  describe '#deadline' do
    it 'formats the time in Warsaw time' do
      expect(section.deadline(end_at)).to eq('15.12.2026 23:59')
    end

    it 'is nil without a time' do
      expect(section.deadline(nil)).to be_nil
    end
  end

  describe '#nominees' do
    it 'lists the nominated people' do
      person = create(:user, first_name: 'Jan', last_name: 'Kowalski')
      request = nomination(category: category_a, nominees: [person])

      expect(section.nominees(request)).to eq(person.display_name)
    end
  end
end
