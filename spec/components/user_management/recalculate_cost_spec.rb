# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserManagement::RecalculateCost do
  def profile(accepted:, payment_state:)
    record = create(:profile)
    record.update_column(:accepted, accepted)
    create(:payment, state: payment_state, payable: record)
    record
  end

  let!(:unpaid)   { profile(accepted: false, payment_state: 'unpaid') }
  let!(:paid)     { profile(accepted: false, payment_state: 'prepaid') }
  let!(:accepted) { profile(accepted: true, payment_state: 'unpaid') }

  describe '#candidates' do
    it 'selects unaccepted profiles with an unpaid payment' do
      expect(described_class.new.candidates).to contain_exactly(unpaid)
    end
  end

  describe '#all' do
    it 'enqueues one recalculation per candidate' do
      worker = class_spy(UserManagement::Workers::ProfileRecalculateCostWorker)
      stub_const('UserManagement::Workers::ProfileRecalculateCostWorker', worker)

      described_class.new.all

      expect(worker).to have_received(:perform_async).with(unpaid.id).once
      expect(worker).to have_received(:perform_async).once
    end
  end
end
