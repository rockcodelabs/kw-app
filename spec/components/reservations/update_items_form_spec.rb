# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Reservations::UpdateItemsForm do
  subject(:form) { described_class.new }

  it 'accepts an id and an items string' do
    expect(form.call(id: '1', items_ids: '101 102')).to be_success
  end

  %i[id items_ids].each do |key|
    it "requires #{key}" do
      expect(form.call({ id: '1', items_ids: '101', key => '' }).errors.to_h).to have_key(key)
    end
  end

  it 'rejects an array for items_ids' do
    expect(form.call(id: '1', items_ids: %w[101])).to be_failure
  end
end
