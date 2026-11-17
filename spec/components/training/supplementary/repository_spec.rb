# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Training::Supplementary::Repository do
  let!(:course) { Training::Supplementary::CourseRecord.create!(name: 'Kurs', place: 'Kraków', state: :published) }
  let(:past) { 2.days.ago }

  def sign_up(email:, sent_at:, expired_at:, payment_state: 'unpaid')
    record = Training::Supplementary::SignUpRecord.create!(
      course_id: course.id, name: 'Jan', email: email, sent_at: sent_at, expired_at: expired_at
    )
    create(:payment, state: payment_state, payable: record)
    record
  end

  # Rails 6.1 changed `where.not(a: nil, b: nil)` from `a IS NOT NULL AND b IS NOT NULL`
  # to `NOT (a IS NULL AND b IS NULL)`. The cron task destroys what this returns.
  describe '#expired_sign_ups' do
    it 'returns only unpaid sign ups that were sent and have expired' do
      expired     = sign_up(email: 'a@example.com', sent_at: past, expired_at: past)
      never_sent  = sign_up(email: 'b@example.com', sent_at: nil, expired_at: past)
      no_deadline = sign_up(email: 'c@example.com', sent_at: past, expired_at: nil)
      on_hold     = sign_up(email: 'd@example.com', sent_at: nil, expired_at: nil)
      not_expired = sign_up(email: 'e@example.com', sent_at: past, expired_at: 2.days.from_now)
      paid        = sign_up(email: 'f@example.com', sent_at: past, expired_at: past, payment_state: 'prepaid')

      result = described_class.new.expired_sign_ups

      expect(result).to contain_exactly(expired)
      expect(result).not_to include(never_sent, no_deadline, on_hold, not_expired, paid)
    end
  end
end
