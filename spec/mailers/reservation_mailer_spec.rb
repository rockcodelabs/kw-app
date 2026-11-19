# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReservationMailer, type: :mailer do
  let(:user) { create(:user, :with_membership, :with_profile) }
  let(:item) { create(:item, display_name: 'Czekan Petzl') }
  let(:reservation) do
    create(:reservation, user: user, start_date: '2030-01-03', end_date: '2030-01-10').tap do |r|
      r.items << item
      r.create_payment(dotpay_id: SecureRandom.hex(13))
    end
  end

  describe '#remind' do
    subject(:mail) { described_class.remind(reservation) }

    it 'goes to the member from the office mailbox and names the item' do
      expect(mail.to).to eq([user.email])
      expect(mail.from).to eq(['biuro@kw.krakow.pl'])
      expect(mail.subject).to eq('Przypominamy o oddaniu: Czekan Petzl')
    end

    it 'renders the body' do
      expect { mail.body.encoded }.not_to raise_error
    end

    it 'is a no-op for a reservation that no longer exists' do
      expect(described_class.remind(nil).message).to be_a(ActionMailer::Base::NullMail)
    end
  end

  describe '#reserve' do
    subject(:mail) { described_class.reserve(reservation) }

    it 'confirms the reservation to the member and links to the payment' do
      expect(mail.to).to eq([user.email])
      expect(mail.subject).to eq('Zarezerwowano: Czekan Petzl')
      expect(mail.body.encoded).to include("/payments/#{reservation.payment.id}/charge")
    end
  end
end
