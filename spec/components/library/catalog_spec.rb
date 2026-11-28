# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Library::Catalog do
  it 'has unique disciplines' do
    expect(described_class::DISCIPLINES).to eq(described_class::DISCIPLINES.uniq)
  end

  it 'has unique countries' do
    expect(described_class::COUNTRIES).to eq(described_class::COUNTRIES.uniq)
  end

  it 'includes the core guide types and countries' do
    expect(described_class::DISCIPLINES).to include('wspinaczkowy', 'skiturowy', 'trekkingowy')
    expect(described_class::COUNTRIES).to include('Polska', 'Słowacja', 'Hiszpania')
  end

  it 'is frozen' do
    expect(described_class::DISCIPLINES).to be_frozen
    expect(described_class::COUNTRIES).to be_frozen
  end
end
