# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Homepage Klubowa Ósemka section', type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:start_at) { Time.utc(2026, 12, 11, 6, 0) }
  let(:end_at) { Time.utc(2026, 12, 15, 22, 59) }
  let!(:edition) { create(:yearly_prize_edition, year: 2026, start_voting_date: start_at, end_voting_date: end_at) }
  let!(:category) { create(:yearly_prize_category, yearly_prize_edition: edition, name: 'Ósemka STJ') }
  let!(:other_category) { create(:yearly_prize_category, yearly_prize_edition: edition, name: 'Ósemka SNW') }
  let(:nominee) { create(:user, first_name: 'Jan', last_name: 'Kowalski') }
  let!(:chosen) do
    create(:yearly_prize_request, yearly_prize_edition: edition, yearly_prize_category: category,
                                  prize_jury_description: 'Wielkie przejście zimą', nominees: [nominee])
  end
  let!(:other) do
    create(:yearly_prize_request, yearly_prize_edition: edition, yearly_prize_category: other_category,
                                  author_description: 'Drugie przejście latem')
  end

  def page
    Nokogiri::HTML(response.body)
  end

  def section
    page.at_css('#yearly-prize-home')
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

  it 'is hidden on 1 January even though the old edition has results' do
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

    it 'invites to submit and links to the regulamin, with the deadlines' do
      expect(section.text).to include('Klubowa Ósemka 2026')
      expect(section.at_css('a[href="/osemka/2026/zgloszenie"]')).to be_present
      expect(section.at_css('a[href="/osemka/regulamin"]')).to be_present
      expect(section.text).to include('11.12.2026')
      expect(section.text).to include('15.12.2026')
    end

    it 'shows the categories but no vote buttons' do
      expect(section.text).to include('Ósemka STJ', 'Ósemka SNW')
      expect(section.css('form[action="/likes"]')).to be_empty
    end
  end

  describe 'while voting is open' do
    it 'shows every nomination grouped by category with a vote button' do
      visit_home_at(start_at + 1.day)

      expect(section.text).to include('Ósemka STJ', 'Ósemka SNW', 'Jan Kowalski', 'Wielkie przejście zimą', 'Drugie przejście latem')
      expect(section.css('form[action="/likes"]').size).to eq(2)
      expect(section.at_css("a[href='/osemka/2026/zgloszenie/#{chosen.id}']")).to be_present
      expect(section.at_css('a[href="/osemka/regulamin"]')).to be_present
    end

    it 'shows only the voted nomination with an undo button after the user voted' do
      visit_home_at(start_at + 1.day) { |member| create(:like, user: member, likeable: chosen) }

      expect(section.text).to include('Wielkie przejście zimą')
      expect(section.text).not_to include('Drugie przejście latem')
      expect(section.css('form[action="/likes"]')).to be_empty
      expect(section.css('form input[name="_method"][value="delete"]').size).to eq(1)
    end

    it 'does not show vote counts' do
      create(:like, likeable: chosen)
      visit_home_at(start_at + 1.day)

      expect(section.css('.yearly-prize-votes')).to be_empty
    end
  end

  describe 'after voting ended' do
    before do
      create_list(:like, 2, likeable: chosen)
      create(:like, likeable: other)
      visit_home_at(end_at + 1.hour)
    end

    it 'shows the ranking with vote counts and no vote buttons' do
      expect(section.text).to include('Wyniki', 'Jan Kowalski')
      expect(section.css('.yearly-prize-votes').map { |node| node.text.strip }).to contain_exactly('2 głosy', '1 głos')
      expect(section.css('form')).to be_empty
    end
  end

  describe 'when the edition is closed' do
    it 'shows results even if the end date is still ahead' do
      edition.update!(closed: true)
      visit_home_at(start_at + 1.day)

      expect(section.text).to include('Wyniki')
      expect(section.css('form')).to be_empty
    end
  end
end
