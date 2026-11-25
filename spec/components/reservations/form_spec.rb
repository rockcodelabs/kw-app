# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Reservations::Form do
  before { Timecop.freeze('2016-08-14'.to_date) } # Sunday
  after { Timecop.return }

  def form(overrides = {})
    described_class.new({ start_date: '2016-08-18', end_date: '2016-08-25', item_ids: [1] }.merge(overrides))
  end

  it 'is valid for a Thursday-to-Thursday week in the future with items' do
    expect(form).to be_valid
  end

  it 'accepts a start date today when today is a Thursday' do
    Timecop.freeze('2016-08-18'.to_date) do
      expect(form).to be_valid
    end
  end

  it 'requires at least one item' do
    f = form(item_ids: [])

    expect(f).not_to be_valid
    expect(f.errors[:item_ids]).to be_present
  end

  it 'requires the start date to be a Thursday' do
    f = form(start_date: '2016-08-17', end_date: '2016-08-25')

    expect(f).not_to be_valid
    expect(f.errors[:start_date]).to include('has to be thursday')
  end

  it 'requires the end date to be a Thursday' do
    f = form(end_date: '2016-08-24')

    expect(f).not_to be_valid
    expect(f.errors[:end_date]).to include('has to be thursday')
  end

  it 'refuses a start date in the past' do
    f = form(start_date: '2016-08-11', end_date: '2016-08-18')

    expect(f).not_to be_valid
    expect(f.errors[:start_date]).to include('cannot be in the past')
  end

  it 'refuses an end date that is not after the start date' do
    f = form(start_date: '2016-08-25', end_date: '2016-08-18')

    expect(f).not_to be_valid
    expect(f.errors[:end_date]).to include('cannot be before start_date')
  end

  it 'refuses a period longer than one week' do
    f = form(end_date: '2016-09-01')

    expect(f).not_to be_valid
    expect(f.errors[:end_date]).to include('has to be one week later')
  end

  describe '#items' do
    it 'loads the items by id' do
      item = create(:item)
      create(:item)

      expect(form(item_ids: [item.id]).items).to contain_exactly(item)
    end
  end

  describe 'date readers' do
    it 'return dates, not strings' do
      f = form

      expect(f.start_date).to eq(Date.new(2016, 8, 18))
      expect(f.end_date).to eq(Date.new(2016, 8, 25))
    end
  end
end
