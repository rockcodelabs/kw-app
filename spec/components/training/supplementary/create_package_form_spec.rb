# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Training::Supplementary::CreatePackageForm do
  subject(:result) { described_class.new.call(params) }

  let(:params) { { name: 'Pakiet', cost: '100', course_id: '1' } }

  it { is_expected.to be_success }

  it 'accepts the optional membership flag' do
    expect(described_class.new.call(params.merge(membership: '1'))).to be_success
  end

  %i[name cost course_id].each do |key|
    it "requires #{key}" do
      result = described_class.new.call(params.merge(key => ''))

      expect(result).to be_failure
      expect(result.errors.to_h.keys).to eq([key])
    end
  end
end
