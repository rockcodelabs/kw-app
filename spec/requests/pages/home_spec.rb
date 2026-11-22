# frozen_string_literal: true

require 'rails_helper'

# The homepage "Nadchodzące wydarzenia" block used to be a React component that
# fetched /supplementary/api/courses?order=start_date and rendered the first 3
# events (calendar icon, name, arrow) plus a "Więcej" link when there were more
# than 3. It is now rendered on the server. These specs keep both in sync by
# comparing the homepage with what the old widget received from that endpoint.
RSpec.describe 'Homepage upcoming events', type: :request do
  let(:polish_abbr_months) { %w[sty lut mar kwi maj cze lip sie wrz paź lis gru] }
  let(:member) { create(:user, :with_membership, :with_profile) }

  def create_course(name:, start_date:, state: :published, category: :kw)
    Training::Supplementary::CourseRecord.create!(
      name: name, place: 'Kraków', state: state, category: category,
      payment_type: :trainings, start_date: start_date
    )
  end

  def weeks_from_now_at_noon(weeks)
    weeks.weeks.from_now.change(hour: 12)
  end

  # What the React widget received and rendered from.
  def legacy_events
    get '/supplementary/api/courses?order=start_date'
    JSON.parse(response.body)
  end

  def rendered_events
    get '/'
    Nokogiri::HTML(response.body).css('.upcoming-events .upcoming-event')
  end

  def more_link
    Nokogiri::HTML(response.body).at_css('.upcoming-events .upcoming-events-more')
  end

  before { sign_in member }

  it 'renders upcoming published events on the server, soonest first' do
    later = create_course(name: 'Późniejszy kurs', start_date: weeks_from_now_at_noon(3))
    sooner = create_course(name: 'Wcześniejszy kurs', start_date: weeks_from_now_at_noon(1))

    get '/'

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Nadchodzące wydarzenia')
    expect(response.body).not_to include('events_component')
    expect(response.body).to include("/supplementary/courses/#{sooner.id}", "/supplementary/courses/#{later.id}")
    expect(response.body.index('Wcześniejszy kurs')).to be < response.body.index('Późniejszy kurs')
  end

  it 'keeps the heading linking to the events list' do
    get '/'

    heading_link = Nokogiri::HTML(response.body).at_css('a[href="/supplementary/courses"] h4')
    expect(heading_link&.text).to eq('Nadchodzące wydarzenia')
  end

  describe 'parity with the former React widget' do
    it 'shows the same events, in the same order, as the API feed (first 3)' do
      [4, 1, 3, 2].each { |weeks| create_course(name: "Kurs za #{weeks} tyg.", start_date: weeks_from_now_at_noon(weeks)) }

      expected = legacy_events.first(3)
      cards = rendered_events

      expect(cards.size).to eq(3)
      expect(cards.map { |card| card['href'] }).to eq(expected.map { |event| "/supplementary/courses/#{event['id']}" })
      expect(cards.map { |card| card.at_css('.upcoming-event-name').text.strip }).to eq(expected.map { |event| event['name'] })
    end

    it 'shows the same calendar icon (day and month) for each event' do
      [1, 2, 3].each { |weeks| create_course(name: "Kurs za #{weeks} tyg.", start_date: weeks_from_now_at_noon(weeks)) }

      expected = legacy_events.first(3)
      cards = rendered_events

      expected.zip(cards).each do |event, card|
        # The old component showed the day in the viewer's (Polish) browser time zone.
        starts_at = Time.zone.parse(event['start_date']).in_time_zone('Europe/Warsaw')

        expect(card.at_css('.upcoming-event-day').text.strip).to eq(starts_at.day.to_s)
        expect(card.at_css('.upcoming-event-month').text.strip).to eq(polish_abbr_months[starts_at.month - 1])
        expect(card.at_css('.upcoming-event-date')['title']).to eq(starts_at.to_date.to_s)
      end
    end

    it 'shows the Polish calendar day even when UTC is still the previous day' do
      # 23:30 UTC on Dec 1st is already 00:30 on Dec 2nd in Warsaw (CET).
      year = Time.current.year + 1
      create_course(name: 'Nocny kurs', start_date: Time.utc(year, 12, 1, 23, 30))

      expected = legacy_events.first
      card = rendered_events.first

      expect(expected['start_date']).to start_with("#{year}-12-01T23:30")
      expect(card.at_css('.upcoming-event-day').text.strip).to eq('2')
      expect(card.at_css('.upcoming-event-month').text.strip).to eq('gru')
    end

    it 'renders the trailing arrow on every row like the old list' do
      create_course(name: 'Kurs', start_date: weeks_from_now_at_noon(1))

      expect(rendered_events.map { |card| card.at_css('.upcoming-event-arrow').text.strip }).to eq(['>'])
    end

    it 'includes every category, like the API without a category filter' do
      %i[kw snw sww web].each_with_index do |category, index|
        create_course(name: "Kategoria #{category}", start_date: weeks_from_now_at_noon(index + 1), category: category)
      end

      expected = legacy_events.first(3)

      expect(rendered_events.map { |card| card['href'] }).to eq(expected.map { |event| "/supplementary/courses/#{event['id']}" })
      expect(expected.size).to eq(3)
    end

    it 'excludes drafts, cancelled, archived and past events, like the API' do
      create_course(name: 'Szkic kursu', start_date: weeks_from_now_at_noon(1), state: :draft)
      create_course(name: 'Odwołany kurs', start_date: weeks_from_now_at_noon(1), state: :cancelled)
      create_course(name: 'Zarchiwizowany kurs', start_date: weeks_from_now_at_noon(1), state: :archived)
      create_course(name: 'Stary kurs', start_date: 1.week.ago)
      create_course(name: 'Opublikowany kurs', start_date: weeks_from_now_at_noon(1))

      expect(legacy_events.map { |event| event['name'] }).to eq(['Opublikowany kurs'])
      expect(rendered_events.map { |card| card.at_css('.upcoming-event-name').text.strip }).to eq(['Opublikowany kurs'])
    end

    it 'includes an event that started earlier today, like the API' do
      create_course(name: 'Dzisiejszy kurs', start_date: Time.current.beginning_of_day + 1.minute)

      expect(legacy_events.map { |event| event['name'] }).to eq(['Dzisiejszy kurs'])
      expect(rendered_events.map { |card| card.at_css('.upcoming-event-name').text.strip }).to eq(['Dzisiejszy kurs'])
    end

    describe '"Więcej" link' do
      it 'is absent with no events (API empty too)' do
        expect(legacy_events).to be_empty

        expect(rendered_events).to be_empty
        expect(more_link).to be_nil
      end

      it 'is absent with exactly 3 events (the old widget needed more than 3)' do
        3.times { |i| create_course(name: "Kurs #{i}", start_date: weeks_from_now_at_noon(i + 1)) }

        expect(legacy_events.size).to eq(3)
        expect(rendered_events.size).to eq(3)
        expect(more_link).to be_nil
      end

      it 'is shown with 4 events and links to the events list, showing only 3 rows' do
        4.times { |i| create_course(name: "Kurs #{i}", start_date: weeks_from_now_at_noon(i + 1)) }

        expect(legacy_events.size).to eq(4)
        expect(rendered_events.size).to eq(3)
        expect(more_link&.text).to eq('Więcej')
        expect(more_link['href']).to eq('/supplementary/courses')
      end

      it 'is shown with many events' do
        6.times { |i| create_course(name: "Kurs #{i}", start_date: weeks_from_now_at_noon(i + 1)) }

        expect(legacy_events.size).to eq(6)
        expect(rendered_events.size).to eq(3)
        expect(more_link).to be_present
      end
    end
  end
end
