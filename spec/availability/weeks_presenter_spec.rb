# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Availability::WeeksPresenter do
  before { Timecop.freeze('2026-11-25'.to_date) } # Wednesday
  after { Timecop.return }

  let(:options) { described_class.to_options }
  let(:week_options) { options.flat_map(&:last) }

  it 'groups the weeks by month: [label, [[text, date], ...]]' do
    expect(options).not_to be_empty
    options.each do |label, weeks|
      expect(label).to be_a(String)
      expect(weeks).to all(match([a_kind_of(String), a_string_matching(/\A\d{4}-\d{2}-\d{2}\z/)]))
    end
  end

  it 'offers only Thursdays' do
    expect(week_options.map { |_, date| Date.parse(date) }).to all(be_thursday)
  end

  it 'offers no week in the past' do
    expect(week_options.map { |_, date| Date.parse(date) }).to all(be >= Date.new(2026, 11, 25))
  end

  it 'starts with the nearest Thursday' do
    expect(week_options.first.last).to eq('2026-11-26')
  end

  it 'does not list the same Thursday twice' do
    dates = week_options.map(&:last)

    expect(dates).to eq(dates.uniq)
  end
end
