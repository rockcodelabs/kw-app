# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Business::Repository do
  let!(:course) { Business::CourseRecord.new(slug: 'kurs').tap { |c| c.save!(validate: false) } }
  let(:past) { 2.days.ago }

  def sign_up(sent_at:, expired_at:)
    record = Business::SignUpRecord.new(course_id: course.id, phone: '500100200', sent_at: sent_at, expired_at: expired_at)
    record.save!(validate: false)
    create(:payment, state: 'unpaid', payable: record)
    record
  end

  # See Training::Supplementary::Repository spec: Rails 6.1 `where.not(a: nil, b: nil)` change.
  describe '#expired_sign_ups' do
    it 'returns only unpaid sign ups that were sent and have expired' do
      expired     = sign_up(sent_at: past, expired_at: past)
      never_sent  = sign_up(sent_at: nil, expired_at: past)
      no_deadline = sign_up(sent_at: past, expired_at: nil)

      result = described_class.new.expired_sign_ups

      expect(result).to contain_exactly(expired)
      expect(result).not_to include(never_sent, no_deadline)
    end
  end
end
