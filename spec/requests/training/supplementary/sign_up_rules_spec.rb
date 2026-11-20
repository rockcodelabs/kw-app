# frozen_string_literal: true

require 'rails_helper'

# Business rules behind signing up to a course: who is allowed in (fees), how many fit, and what
# happens to the money record and the mails when a sign-up is removed.
RSpec.describe 'Training::Supplementary sign-up rules', type: :request do
  let(:paying_member) { create(:user, :with_membership, :with_profile) }
  let(:unpaid_member) { create(:user, :with_profile) }
  let(:events_user) { create(:user, :with_events_role, :with_membership, :with_profile) }

  let!(:course) do
    Training::Supplementary::CourseRecord.create!(
      name: 'Kurs lodowy', place: 'Kraków', state: :published, payment_type: :trainings, price: true,
      price_kw: 150, start_date: 2.weeks.from_now, end_date: 2.weeks.from_now + 1.day
    )
  end

  def post_sign_up(user, **extra)
    post supplementary_sign_ups_path,
         params: { sign_up: { name: user.display_name, email: user.email, user_id: user.id.to_s, course_id: course.id.to_s }.merge(extra) }
  end

  before { ActiveJob::Base.queue_adapter = :test }

  describe 'courses limited to members with paid fees (last_fee_paid)' do
    before { course.update!(last_fee_paid: true) }

    it 'lets a member with a paid fee sign up' do
      sign_in paying_member

      expect { post_sign_up(paying_member) }.to change(Training::Supplementary::SignUpRecord, :count).by(1)
    end

    it 'refuses a member without a paid fee and tells them why' do
      sign_in unpaid_member

      expect { post_sign_up(unpaid_member) }.not_to change(Training::Supplementary::SignUpRecord, :count)
      expect(flash[:error]).to be_present
    end

    it 'lets a released or honorary member sign up without a fee' do
      unpaid_member.profile.update!(position: ['honorable_kw'])
      sign_in unpaid_member

      expect { post_sign_up(unpaid_member) }.to change(Training::Supplementary::SignUpRecord, :count).by(1)
    end
  end

  describe 'membership-only packages' do
    let!(:club_package) { course.package_types.create!(name: 'Dla klubowiczów', cost: 100, membership: true) }

    before { course.update!(packages: true) }

    it 'sells the package to a member with a paid fee' do
      sign_in paying_member

      expect { post_sign_up(paying_member, supplementary_course_package_type_id: club_package.id.to_s) }
        .to change(Training::Supplementary::SignUpRecord, :count).by(1)
    end

    it 'refuses it to a member without a paid fee' do
      sign_in unpaid_member

      expect { post_sign_up(unpaid_member, supplementary_course_package_type_id: club_package.id.to_s) }
        .not_to change(Training::Supplementary::SignUpRecord, :count)
    end

    it 'refuses it to a guest' do
      expect do
        post supplementary_sign_ups_path,
             params: { sign_up: { name: 'Gość', email: 'gosc@example.com', course_id: course.id.to_s,
                                  supplementary_course_package_type_id: club_package.id.to_s } }
      end.not_to change(Training::Supplementary::SignUpRecord, :count)
    end
  end

  describe 'seat limit' do
    before { course.update!(open: false, limit: 1) }

    it 'sends the payment link only to sign-ups that fit within the limit' do
      sign_in paying_member
      expect { post_sign_up(paying_member) }.to have_enqueued_mail(Training::Supplementary::SignUpMailer, :sign_up)

      second = create(:user, :with_membership, :with_profile)
      sign_in second
      jobs_before = ActiveJob::Base.queue_adapter.enqueued_jobs.size
      expect { post_sign_up(second) }.to change(Training::Supplementary::SignUpRecord, :count).by(1)

      expect(ActiveJob::Base.queue_adapter.enqueued_jobs.size).to eq(jobs_before)
      expect(Training::Supplementary::SignUpRecord.order(:id).last.sent_at).to be_nil
    end
  end

  describe 'DELETE destroy' do
    let!(:sign_up) do
      Training::Supplementary::Repository.new
        .sign_up!(name: 'Uczestnik', email: 'uczestnik@example.com', user_id: nil, course_id: course.id, question: nil)
    end

    before { sign_in events_user }

    it 'tells the participant by mail that the sign-up was removed' do
      expect { delete supplementary_sign_up_path(sign_up) }
        .to have_enqueued_mail(Training::Supplementary::SignUpMailer, :deleted_sign_up)
    end

    it 'cancels the pending Dotpay payment link when one exists' do
      sign_up.payment.update!(payment_url: 'https://ssl.dotpay.pl/pay/abc')
      deleter = instance_double(Payments::DeletePayment, delete: true)
      allow(Payments::DeletePayment).to receive(:new).and_return(deleter)

      expect { delete supplementary_sign_up_path(sign_up) }.to change(Training::Supplementary::SignUpRecord, :count).by(-1)

      expect(Payments::DeletePayment).to have_received(:new).with(payment: sign_up.payment)
      expect(deleter).to have_received(:delete)
    end
  end
end
