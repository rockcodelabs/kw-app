# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Training::Supplementary::FillEmptyPlaces do
  before { ActiveJob::Base.queue_adapter = :test }

  subject(:operation) { described_class.new(repository) }

  let(:repository) { Training::Supplementary::Repository.new }
  let!(:course) do
    Training::Supplementary::CourseRecord.create!(name: 'Kurs', place: 'Kraków', state: :published,
                                                  limit: 1, open: false, expired_hours: 24)
  end

  def on_hold_sign_up(email)
    record = Training::Supplementary::SignUpRecord.create!(course_id: course.id, name: 'Jan', email: email)
    create(:payment, payable: record)
    record
  end

  let!(:fits)      { on_hold_sign_up('first@example.com') }
  let!(:waitlist)  { on_hold_sign_up('second@example.com') }

  describe '#candidates' do
    it 'selects the sign ups on hold that fit the limit, and sends nothing' do
      expect(operation.candidates(course_id: course.id)).to contain_exactly(fits)

      expect(fits.reload.sent_at).to be_nil
      expect(Training::Supplementary::SignUpMailer).not_to receive(:sign_up)
    end

    it 'is empty for an unknown course' do
      expect(operation.candidates(course_id: 0)).to be_empty
    end
  end

  describe '#call' do
    it 'sends the payment e-mail to the sign up that fits and keeps the other on hold' do
      expect(operation.call(course_id: course.id)).to be_success

      expect(fits.reload.sent_at).to be_present
      expect(waitlist.reload.sent_at).to be_nil
    end
  end
end
