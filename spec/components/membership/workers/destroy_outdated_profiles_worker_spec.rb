# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Membership::Workers::DestroyOutdatedProfilesWorker do
  def profile(created_at:, accepted: false, payment_state: 'unpaid')
    record = create(:profile)
    record.update_columns(accepted: accepted, created_at: created_at)
    create(:payment, state: payment_state, payable: record)
    record
  end

  let!(:outdated)        { profile(created_at: 4.months.ago) }
  let!(:recent)          { profile(created_at: 1.month.ago) }
  let!(:accepted_member) { profile(created_at: 4.months.ago, accepted: true) }
  let!(:paid)            { profile(created_at: 4.months.ago, payment_state: 'prepaid') }

  describe '.candidates' do
    it 'selects unaccepted, unpaid profiles older than 3 months' do
      expect(described_class.candidates).to contain_exactly(outdated)
    end
  end

  describe '#perform' do
    it 'destroys exactly the candidates' do
      described_class.new.perform

      expect(Db::Profile.exists?(outdated.id)).to be(false)
      expect(Db::Profile.where(id: [recent, accepted_member, paid].map(&:id)).count).to eq(3)
    end
  end
end
