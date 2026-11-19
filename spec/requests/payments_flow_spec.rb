# frozen_string_literal: true

require 'rails_helper'

# Post-deploy critical flow: money. Dotpay callback, charge redirect, cash payment, refund.
RSpec.describe 'Payments flow', type: :request do
  let(:member) { create(:user, :with_membership, :with_profile) }
  let(:events_user) { create(:user, :with_events_role, :with_membership, :with_profile) }

  let!(:course) do
    Training::Supplementary::CourseRecord.create!(
      name: 'Kurs lodowy', place: 'Kraków', state: :published, payment_type: :trainings, price_kw: 150
    )
  end
  let!(:sign_up) do
    Training::Supplementary::Repository.new.sign_up!(
      name: member.display_name, email: member.email, user_id: member.id, course_id: course.id, question: nil
    )
  end
  let(:payment) { sign_up.payment }

  # Finding G23 (accepted, fix after migration): the callback is not signed, so anyone who knows a dotpay_id can mark it paid.
  PENDING_G23_UNSIGNED = 'G23: unsigned Dotpay callback marks a payment paid'
  # Finding G23b: an unknown control value raises NoMethodError (HTTP 500) instead of a clean response.
  PENDING_G23_UNKNOWN = 'G23b: unknown control raises instead of answering cleanly'
  # Finding G27: refund has no authentication or authorization.
  PENDING_G27_REFUND = 'G27: refund is not authenticated or authorized'

  before { ActiveJob::Base.queue_adapter = :test }

  describe 'POST /api/payments/status (Dotpay callback)' do
    it 'marks a sign-up payment as prepaid and answers OK' do
      post status_api_payments_path, params: { control: payment.dotpay_id, operation_status: 'completed' }

      expect(response.body).to eq('OK')
      expect(payment.reload.state).to eq('prepaid')
    end

    it 'is idempotent when Dotpay repeats the callback' do
      2.times { post status_api_payments_path, params: { control: payment.dotpay_id, operation_status: 'completed' } }

      expect(response.body).to eq('OK')
      expect(payment.reload.state).to eq('prepaid')
    end

    it 'leaves the payment unpaid for a rejected operation and echoes the status' do
      post status_api_payments_path, params: { control: payment.dotpay_id, operation_status: 'rejected' }

      expect(response.body).to eq('rejected')
      expect(payment.reload.state).to eq('unpaid')
    end

    it 'marks a reservation payment as prepaid' do
      reservation = create(:reservation)
      reservation_payment = reservation.create_payment(dotpay_id: SecureRandom.hex(13))

      post status_api_payments_path, params: { control: reservation_payment.dotpay_id, operation_status: 'completed' }

      expect(response.body).to eq('OK')
      expect(reservation_payment.reload.state).to eq('prepaid')
    end

    it 'counts a callback-paid sign-up in the course income' do
      post status_api_payments_path, params: { control: payment.dotpay_id, operation_status: 'completed' }

      expect(course.reload.income_sum).to eq(150)
    end

    it 'answers cleanly for an unknown control value', pending: PENDING_G23_UNKNOWN do
      post status_api_payments_path, params: { control: 'does-not-exist', operation_status: 'completed' }

      expect(response).to have_http_status(:ok).or have_http_status(:not_found)
    end

    it 'rejects a completed callback without a valid signature', pending: PENDING_G23_UNSIGNED do
      post status_api_payments_path, params: { control: payment.dotpay_id, operation_status: 'completed', signature: 'bogus' }

      expect(payment.reload.state).to eq('unpaid')
    end
  end

  describe 'POST /api/payments/thank_you' do
    it 'redirects to /payments after a successful payment' do
      post thank_you_api_payments_path, params: { status: 'OK' }

      expect(response).to redirect_to(payments_path)
    end
  end

  describe 'GET charge (redirect to Dotpay)' do
    before { sign_in member }

    it 'stores the payment url and redirects to it' do
      url = 'https://ssl.dotpay.pl/test_payment/?pid=abc'
      creator = instance_double(Payments::CreatePayment, create: Success.new(payment_url: url))
      allow(Payments::CreatePayment).to receive(:new).with(payment: payment).and_return(creator)

      get charge_payment_path(payment)

      expect(response).to redirect_to(url)
      expect(payment.reload.payment_url).to eq(url)
    end

    it 'refuses when the course limit is already reached by paid sign-ups' do
      course.update!(open: false, limit: 1)
      other = Training::Supplementary::Repository.new.sign_up!(
        name: 'Ktoś', email: 'ktos@example.com', user_id: nil, course_id: course.id, question: nil
      )
      other.payment.update!(state: 'prepaid')
      expect(Payments::CreatePayment).not_to receive(:new)

      get charge_payment_path(payment)

      expect(response).to have_http_status(:redirect)
      expect(flash[:alert]).to eq('Limit zapisów został wykorzystany!')
    end
  end

  describe 'PUT mark_as_paid (cash)' do
    it 'lets an events user mark a payment as paid in cash' do
      sign_in events_user

      put mark_as_paid_payment_path(payment)

      payment.reload
      expect(payment.state).to eq('prepaid')
      expect(payment.cash).to be(true)
      expect(payment.cash_user_id).to eq(events_user.id)
    end

    it 'does not let a plain member mark a payment as paid' do
      sign_in member

      put mark_as_paid_payment_path(payment)

      expect(payment.reload.state).to eq('unpaid')
      expect(flash[:alert]).to eq('Nie masz uprawnień')
    end

    it 'does not let an anonymous visitor mark a payment as paid' do
      put mark_as_paid_payment_path(payment)

      expect(payment.reload.state).to eq('unpaid')
    end
  end

  describe 'POST refund' do
    it 'does not call Dotpay for an anonymous visitor', pending: PENDING_G27_REFUND do
      expect(Payments::Dotpay::GetOperationRequest).not_to receive(:new)

      post refund_payment_path(payment)
    end
  end
end
