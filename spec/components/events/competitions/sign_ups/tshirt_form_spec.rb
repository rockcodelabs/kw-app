# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Events::Competitions::SignUps::TshirtForm do
  subject(:form) { described_class.new(competition_id: competition.id) }

  let!(:competition) { Events::Db::CompetitionRecord.create!(name: 'Zawody', edition_sym: 'z', email_text: 'x', event_date: 1.month.from_now) }
  let!(:package) { competition.package_types.create!(name: 'Poza KW', cost: 60) }
  let(:params) { { participant_name_1: 'Jan', tshirt_size_1: 'M', competition_package_type_1_id: package.id.to_s } }

  it 'accepts valid params and coerces the package id' do
    result = form.call(params)

    expect(result).to be_success
    expect(result[:competition_package_type_1_id]).to eq(package.id)
  end

  %i[participant_name_1 tshirt_size_1 competition_package_type_1_id].each do |key|
    it "requires #{key}" do
      expect(form.call(params.merge(key => '')).errors.to_h).to have_key(key)
    end
  end

  context 'with a membership package' do
    before { package.update!(membership: true) }

    it 'requires an active member' do
      expect(form.call(params.merge(participant_kw_id_1: '99999')).errors(locale: :pl).to_h[:participant_kw_id_1])
        .to eq(['Musisz podać numer legitymacji klubu 1 z opłaconą składką'])
    end
  end
end
