# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PhotoCompetition::HomeSection do
  let(:user) { create(:user) }
  let(:start_at) { Time.utc(2026, 12, 11, 6, 0) }
  let(:end_at) { Time.utc(2026, 12, 15, 22, 59) }
  let(:now) { Time.utc(2026, 12, 12, 12, 0) }
  let!(:edition) { create(:photo_competition_edition, code: 'kasprzyk_2026', start_voting_date: start_at, end_voting_date: end_at) }
  let!(:summer) { create(:photo_competition_category, edition: edition, name: 'Góry latem') }
  let!(:winter) { create(:photo_competition_category, edition: edition, name: 'Góry zimą') }

  subject(:section) { described_class.new(user: user, now: now) }

  def photo(category: summer, likes: 0, **attrs)
    create(:photo_competition_request, edition: edition, category: category, **attrs).tap do |record|
      likes.times { create(:like, likeable: record) }
    end
  end

  describe '#stage' do
    it 'is hidden when there is no edition for the current year' do
      edition.update!(code: 'kasprzyk_2025')

      expect(section.stage).to eq(:hidden)
      expect(section.visible?).to be(false)
    end

    it 'is hidden from 1 January (Warsaw time)' do
      expect(described_class.new(user: user, now: Time.utc(2026, 12, 31, 23, 0)).stage).to eq(:hidden)
    end

    it 'still shows results on the last evening of the year (Warsaw time)' do
      expect(described_class.new(user: user, now: Time.utc(2026, 12, 31, 22, 59)).stage).to eq(:results)
    end

    it 'is submissions before voting starts, or without a start date' do
      expect(described_class.new(user: user, now: start_at - 1.day).stage).to eq(:submissions)

      edition.update!(start_voting_date: nil)
      expect(section.stage).to eq(:submissions)
    end

    it 'is voting while voting is open, whether or not the user voted' do
      expect(section.stage).to eq(:voting)

      create(:like, user: user, likeable: photo)
      expect(described_class.new(user: user, now: now).stage).to eq(:voting)
    end

    it 'is results after the end date or when the edition is closed' do
      expect(described_class.new(user: user, now: end_at + 1.minute).stage).to eq(:results)

      edition.update!(closed: true)
      expect(section.stage).to eq(:results)
    end
  end

  describe '#my_votes and #votes_left' do
    it 'lists the photos the user voted for in this edition' do
      mine = photo
      create(:like, user: user, likeable: mine)
      create(:like, likeable: photo)
      create(:like, user: user, likeable: create(:photo_competition_request))

      expect(section.my_votes).to eq([mine])
      expect(section.votes_left).to eq(2)
    end

    it 'never reports negative votes left' do
      4.times { create(:like, user: user, likeable: photo) }

      expect(section.votes_left).to eq(0)
    end
  end

  describe '#daily_picks' do
    before { 12.times { photo } }

    it 'offers up to 4 accepted photos the user has not voted for' do
      photo(accepted: false)
      voted = photo
      create(:like, user: user, likeable: voted)

      picks = section.daily_picks

      expect(picks.size).to eq(4)
      expect(picks).to all(have_attributes(accepted: true))
      expect(picks).not_to include(voted)
    end

    it 'is stable during a day and changes from day to day' do
      same_day = described_class.new(user: user, now: now + 3.hours).daily_picks.map(&:id)
      other_days = (1..6).map { |days| described_class.new(user: user, now: now + days.days).daily_picks.map(&:id) }

      expect(section.daily_picks.map(&:id)).to eq(same_day)
      expect(other_days.uniq.size).to be > 1
    end

    it 'is empty once the user used all 3 votes' do
      3.times { create(:like, user: user, likeable: photo) }

      expect(section.daily_picks).to be_empty
    end
  end

  describe '#results' do
    it 'ranks accepted photos by votes within each category, top 3 only' do
      leader = photo(likes: 3)
      second = photo(likes: 2)
      third = photo(likes: 1)
      photo(likes: 0)
      photo(accepted: false, likes: 5)
      winter_only = photo(category: winter, likes: 1)
      edition.update!(closed: true)

      results = section.results

      expect(results.map { |group| group.category.name }).to eq(['Góry latem', 'Góry zimą'])
      expect(results.first.entries.map(&:photo)).to eq([leader, second, third])
      expect(results.first.entries.map(&:rank)).to eq([1, 2, 3])
      expect(results.last.entries.map(&:photo)).to eq([winter_only])
    end

    it 'gives tied photos the same rank' do
      photo(likes: 2)
      photo(likes: 2)
      photo(likes: 1)
      edition.update!(closed: true)

      expect(section.results.first.entries.map(&:rank)).to eq([1, 1, 3])
    end

    it 'skips categories without accepted photos' do
      photo(category: summer, accepted: false)
      edition.update!(closed: true)

      expect(section.results).to be_empty
    end
  end

  describe 'paths and labels' do
    it 'exposes the gallery, submission and photo paths' do
      record = photo

      expect(section.gallery_path).to eq('/konkurs/kasprzyk_2026/glosowanie')
      expect(section.submit_path).to eq('/konkurs/kasprzyk_2026')
      expect(section.photo_path(record)).to eq("/editions/kasprzyk_2026/requests/#{record.id}")
    end

    it 'formats votes and deadlines like the Ósemka section' do
      expect(section.votes_label(2)).to eq('2 głosy')
      expect(section.deadline(end_at)).to eq('15.12.2026 23:59')
    end
  end
end
