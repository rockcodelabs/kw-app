# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Events::Admin::Competitions::CreateForm do
  subject(:form) { described_class.new }

  let(:params) { { name: 'Zawody', email_text: 'Dziękujemy', edition_sym: 'zawody' } }

  it 'accepts the required params' do
    expect(form.call(params)).to be_success
  end

  %i[name email_text edition_sym].each do |key|
    it "requires #{key}" do
      expect(form.call(params.merge(key => '')).errors.to_h).to have_key(key)
    end
  end

  it 'keeps the optional competition attributes' do
    result = form.call(params.merge(event_date: '2027-03-01', limit: '10', custom_form: 'mas', rules_text: 'R', organizer_email: 'o@example.com'))

    expect(result.to_h).to include(event_date: '2027-03-01', limit: '10', custom_form: 'mas', rules_text: 'R', organizer_email: 'o@example.com')
  end

  it 'drops undeclared keys' do
    expect(form.call(params.merge(id: 1)).to_h).not_to have_key(:id)
  end
end
