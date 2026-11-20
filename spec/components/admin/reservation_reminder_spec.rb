# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::ReservationReminder do
  before { ActiveJob::Base.queue_adapter = :test }

  let!(:ended_yesterday) { create(:reservation, end_date: 1.day.ago.to_date) }
  let!(:ended_today)     { create(:reservation, end_date: Date.current) }
  let!(:ended_earlier)   { create(:reservation, end_date: 5.days.ago.to_date) }

  describe '.candidates' do
    it 'selects the reservations whose end date was yesterday' do
      expect(described_class.candidates).to contain_exactly(ended_yesterday)
    end
  end

  describe '.send_reminders' do
    it 'mails exactly the candidates' do
      expect { described_class.send_reminders }
        .to have_enqueued_mail(ReservationMailer, :remind).once
    end
  end
end
