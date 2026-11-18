# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Reservations::Workers::DestroyUnpaidReservationsWorker do
  def reservation(created_at:, payment_traits: [])
    record = create(:reservation)
    record.update_column(:created_at, created_at)
    create(:payment, *payment_traits, payable: record)
    record
  end

  let!(:unpaid_old)     { reservation(created_at: 3.days.ago) }
  let!(:unpaid_recent)  { reservation(created_at: 1.day.ago) }
  let!(:prepaid_old)    { reservation(created_at: 3.days.ago, payment_traits: [:prepaid]) }
  let!(:cash_old)       { reservation(created_at: 3.days.ago, payment_traits: [:cash]) }

  describe '.candidates' do
    it 'selects unpaid reservations older than 2 days, except those paid in cash' do
      expect(described_class.candidates).to contain_exactly(unpaid_old)
    end
  end

  describe '#perform' do
    it 'destroys exactly the candidates' do
      described_class.new.perform

      expect(Db::Reservation.exists?(unpaid_old.id)).to be(false)
      expect(Db::Reservation.where(id: [unpaid_recent, prepaid_old, cash_old].map(&:id)).count).to eq(3)
    end
  end
end
