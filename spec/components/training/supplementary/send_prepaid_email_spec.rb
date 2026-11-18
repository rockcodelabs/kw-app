# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Training::Supplementary::SendPrepaidEmail do
  let!(:course) do
    Training::Supplementary::CourseRecord.create!(name: 'Kurs', place: 'Kraków', state: :published,
                                                  paid_email: 'Dziękujemy za wpłatę')
  end

  def sign_up(email:, payment_state: 'prepaid', paid_email_sent_at: nil)
    record = Training::Supplementary::SignUpRecord.create!(course_id: course.id, name: 'Jan', email: email,
                                                           paid_email_sent_at: paid_email_sent_at)
    create(:payment, state: payment_state, payable: record)
    record
  end

  let!(:due)        { sign_up(email: 'due@example.com') }
  let!(:already)    { sign_up(email: 'sent@example.com', paid_email_sent_at: 1.day.ago) }
  let!(:unpaid)     { sign_up(email: 'unpaid@example.com', payment_state: 'unpaid') }

  describe '#candidates' do
    it 'selects prepaid sign ups of courses with a paid e-mail that were not mailed yet' do
      expect(described_class.new.candidates).to contain_exactly(due)
    end
  end

  describe '#send_prepaid_emails' do
    it 'enqueues one job per candidate' do
      worker = class_spy(Training::Supplementary::Workers::SendPrepaidEmailsWorker)
      stub_const('Training::Supplementary::Workers::SendPrepaidEmailsWorker', worker)

      described_class.new.send_prepaid_emails

      expect(worker).to have_received(:perform_async).with(due.id).once
      expect(worker).to have_received(:perform_async).once
    end
  end
end
