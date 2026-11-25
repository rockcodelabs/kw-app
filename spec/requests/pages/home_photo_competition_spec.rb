# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Homepage Konkurs Fotograficzny section', type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:start_at) { Time.utc(2026, 12, 11, 6, 0) }
  let(:end_at) { Time.utc(2026, 12, 15, 22, 59) }

  # ApplicationUploader always uses Fog (remote), so generating URLs would call the storage API.
  before { allow_any_instance_of(PhotoCompetition::FileUploader).to receive(:url).and_return('/photo_competitions/photo.jpg') }
  let!(:edition) do
    create(:photo_competition_edition, code: 'kasprzyk_2026', name: 'Konkurs Kasprzyka 2026',
                                       start_voting_date: start_at, end_voting_date: end_at)
  end
  let!(:summer) { create(:photo_competition_category, edition: edition, name: 'Góry latem') }
  let!(:winter) { create(:photo_competition_category, edition: edition, name: 'Góry zimą') }

  def photo(category: summer, likes: 0, **attrs)
    create(:photo_competition_request, edition: edition, category: category, **attrs).tap do |record|
      likes.times { create(:like, likeable: record) }
    end
  end

  def page
    Nokogiri::HTML(response.body)
  end

  def section
    page.at_css('#photo-competition-home')
  end

  def visit_home_at(time)
    travel_to(time) do
      member = create(:user, :with_membership, :with_profile)
      sign_in member
      yield member if block_given?
      get '/'
    end
  end

  it 'is hidden when there is no edition for the current year' do
    visit_home_at(Time.utc(2027, 3, 1, 12, 0))

    expect(response).to have_http_status(:ok)
    expect(section).to be_nil
  end

  it 'is hidden on 1 January' do
    visit_home_at(Time.utc(2026, 12, 31, 23, 30))

    expect(section).to be_nil
  end

  it 'is not shown to members without a paid fee' do
    travel_to(Time.utc(2026, 12, 12, 12, 0)) do
      sign_in create(:user)
      get '/'
    end

    expect(section).to be_nil
  end

  describe 'before voting starts' do
    before { visit_home_at(start_at - 3.days) }

    it 'invites to submit photos and links to the regulamin, with the deadlines' do
      expect(section.text).to include('Konkurs Kasprzyka 2026', 'Góry latem', 'Góry zimą', '11.12.2026', '15.12.2026')
      expect(section.at_css('a[href="/konkurs/kasprzyk_2026"]')).to be_present
      expect(section.at_css('a[href="/konkurs_kasprzyka/regulamin"]')).to be_present
    end

    it 'has no vote buttons' do
      expect(section.css('form')).to be_empty
    end
  end

  describe 'while voting is open' do
    it 'shows the vote counter, daily photos with vote buttons and a link to the gallery' do
      6.times { photo }
      visit_home_at(start_at + 1.day)

      expect(section.text).to include('Twoje głosy: 0/3')
      expect(section.text).to include('Losowe zdjęcia na dziś', 'Wszystkie zgłoszone zdjęcia znajdziesz na stronie głosowania')
      expect(section.at_css('details')).to be_nil
      expect(section.css('form[action="/likes"]').size).to eq(4)
      expect(section.at_css('a[href="/konkurs/kasprzyk_2026/glosowanie"]')).to be_present
      expect(section.at_css('a[href="/konkurs_kasprzyka/regulamin"]')).to be_present
    end

    it 'shows the photos the user voted for with an undo button, and fewer daily photos to choose from' do
      mine = photo(title: 'Moje ulubione')
      6.times { photo }
      visit_home_at(start_at + 1.day) { |member| create(:like, user: member, likeable: mine) }

      expect(section.text).to include('Twoje głosy: 1/3', 'Moje ulubione')
      expect(section.css('form input[name="_method"][value="delete"]').size).to eq(1)
      expect(section.css('form[action="/likes"]').size).to eq(4)
      expect(section.at_css("a[href='/editions/kasprzyk_2026/requests/#{mine.id}']")).to be_present
    end

    it 'offers no new votes once all 3 are used' do
      6.times { photo }
      visit_home_at(start_at + 1.day) do |member|
        edition.photo_requests.limit(3).each { |record| create(:like, user: member, likeable: record) }
      end

      expect(section.text).to include('Twoje głosy: 3/3')
      expect(section.at_css('details')).to be_present
      expect(section.at_css('details[open]')).to be_nil
      expect(section.text).not_to include('Losowe zdjęcia na dziś')
      expect(section.css('form input[name="_method"][value="delete"]').size).to eq(3)
      expect(section.css('form[action="/likes"]')).to be_empty
    end

    it 'does not show vote counts' do
      photo(likes: 2)
      visit_home_at(start_at + 1.day)

      expect(section.css('.photo-competition-votes')).to be_empty
    end

    it 'does not show photos that are not accepted yet' do
      photo(title: 'Czeka na akceptację', accepted: false)
      visit_home_at(start_at + 1.day)

      expect(section.text).not_to include('Czeka na akceptację')
    end
  end

  describe 'after voting ended' do
    before do
      photo(title: 'Zwycięzca', likes: 2)
      photo(title: 'Drugie miejsce', likes: 1)
      photo(category: winter, title: 'Zima', likes: 1)
      visit_home_at(end_at + 1.hour)
    end

    it 'shows the top photos per category with vote counts and no vote buttons' do
      expect(section.text).to include('Wyniki', 'Zwycięzca', 'Drugie miejsce', 'Zima')
      expect(section.css('.photo-competition-votes').map { |node| node.text.strip }).to contain_exactly('2 głosy', '1 głos', '1 głos')
      expect(section.css('form')).to be_empty
    end
  end

  describe 'when the edition is closed' do
    it 'shows results even if the end date is still ahead' do
      photo(likes: 1)
      edition.update!(closed: true)
      visit_home_at(start_at + 1.day)

      expect(section.text).to include('Wyniki')
      expect(section.css('form')).to be_empty
    end
  end

  describe 'placement' do
    it 'renders below the Klubowa Ósemka block' do
      create(:yearly_prize_edition, year: 2026, start_voting_date: start_at, end_voting_date: end_at)
      visit_home_at(start_at + 1.day)

      expect(response.body.index('id="yearly-prize-home"')).to be < response.body.index('id="photo-competition-home"')
    end
  end
end
