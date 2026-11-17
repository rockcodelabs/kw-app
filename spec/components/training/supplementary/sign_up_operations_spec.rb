# frozen_string_literal: true

require 'rails_helper'

# These operations are called by cron/Sidekiq and the admin UI. They once lost
# `include Dry::Monads[:result]` and raised NoMethodError on Success()/Failure().
RSpec.describe 'Training::Supplementary sign up operations' do
  before { ActiveJob::Base.queue_adapter = :test }

  let(:repository) { Training::Supplementary::Repository.new }
  let!(:course) do
    Training::Supplementary::CourseRecord.create!(name: 'Kurs', place: 'Kraków', state: :published, expired_hours: 24)
  end
  let!(:sign_up) do
    Training::Supplementary::SignUpRecord.create!(course_id: course.id, name: 'Jan', email: 'jan@example.com')
  end

  describe Training::Supplementary::DestroySignUp do
    subject(:operation) { described_class.new(repository) }

    it 'fails when the sign up has no payment, and keeps the sign up' do
      result = operation.call(id: sign_up.id)

      expect(result).to be_failure
      expect(Training::Supplementary::SignUpRecord.exists?(sign_up.id)).to be(true)
    end

    it 'destroys the sign up and enqueues the deleted-sign-up mail' do
      create(:payment, payable: sign_up)

      result = nil
      expect { result = operation.call(id: sign_up.id) }.to have_enqueued_mail(Training::Supplementary::SignUpMailer, :deleted_sign_up)

      expect(result).to be_success
      expect(Training::Supplementary::SignUpRecord.exists?(sign_up.id)).to be(false)
    end
  end

  describe Training::Supplementary::SendEmailWithPayment do
    subject(:operation) { described_class.new(repository) }

    it 'fails without a payment' do
      expect(operation.call(id: sign_up.id)).to be_failure
    end

    it 'sets the deadline, marks the sign up as sent and enqueues the mail' do
      create(:payment, payable: sign_up)

      result = nil
      expect { result = operation.call(id: sign_up.id) }.to have_enqueued_mail(Training::Supplementary::SignUpMailer, :sign_up)

      expect(result).to be_success
      expect(sign_up.reload.sent_at).to be_present
      expect(sign_up.expired_at).to be_within(1.minute).of(24.hours.from_now)
    end
  end

  describe Training::Supplementary::FillEmptyPlaces do
    subject(:operation) { described_class.new(repository) }

    it 'succeeds when nobody is on hold' do
      expect(operation.call(course_id: 0)).to be_success
    end

    it 'sends the payment e-mail to a sign up on hold that fits the limit' do
      create(:payment, payable: sign_up)

      expect(operation.call(course_id: course.id)).to be_success
      expect(sign_up.reload.sent_at).to be_present
    end
  end

  describe Training::Supplementary::OpenConversation do
    subject(:operation) { described_class.new(repository) }

    it 'fails when nobody has paid yet' do
      expect(operation.call(course_id: course.id)).to eq(Dry::Monads::Failure(:no_participants))
    end

    it 'fails when the conversation already exists' do
      course.update!(conversation_at: Time.current)

      expect(operation.call(course_id: course.id)).to eq(Dry::Monads::Failure(:already_exists))
    end
  end

  describe Training::Supplementary::AddToConversation do
    subject(:operation) { described_class.new(repository) }

    it 'fails for an unknown course' do
      expect(operation.call(course_id: 0)).to eq(Dry::Monads::Failure(:no_course))
    end

    it 'fails when the course has no conversation' do
      expect(operation.call(course_id: course.id)).to eq(Dry::Monads::Failure(:no_conversation))
    end
  end
end
