# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserManagement::Workers::SetRegularsWorker do
  def candidate_profile(**attrs)
    create(:profile, position: ['candidate'], application_date: 2.years.ago.to_date, **attrs)
  end

  let!(:due)         { candidate_profile }
  let!(:too_recent)  { candidate_profile(application_date: 2.months.ago.to_date) }
  let!(:regular)     { candidate_profile(position: %w[regular]) }

  describe '.candidates' do
    it 'selects members who applied at least a year ago and are not regular yet' do
      expect(described_class.candidates).to contain_exactly(due)
    end
  end

  describe '#perform' do
    it 'makes exactly the candidates regular' do
      described_class.new.perform

      expect(due.reload.position).to include('regular')
      expect(due.position).not_to include('candidate')
      expect(too_recent.reload.position).to eq(['candidate'])
    end
  end
end
