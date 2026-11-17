# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Management::ProjectForm do
  subject(:form) { described_class.new }

  it 'accepts a name only' do
    expect(form.call(name: 'Projekt')).to be_success
  end

  it 'requires a name' do
    result = form.call(name: '')

    expect(result).to be_failure
    expect(result.errors(locale: :pl).to_h[:name]).to eq(['musi być wypełnione'])
  end

  it 'keeps the optional attributes' do
    result = form.call(name: 'P', description: 'Opis', state: 'draft', estimated_time: '3 mies.')

    expect(result.to_h).to include(description: 'Opis', state: 'draft', estimated_time: '3 mies.')
  end

  it 'drops undeclared keys' do
    expect(form.call(name: 'P', admin: true).to_h).not_to have_key(:admin)
  end
end
