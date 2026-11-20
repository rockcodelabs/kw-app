require 'rails_helper'

RSpec.describe PaymentsController, type: :controller do
  let(:payment) { create(:payment) }

  describe 'POST #mark_as_paid' do
    context 'when user is admin' do
      let(:user) { create(:user, roles: ['admin']) }
      
      before { sign_in(user) }

      it 'marks payment as cash paid' do
        post :mark_as_paid, params: { id: payment.id }
        
        payment.reload
        expect(payment.cash).to be true
        expect(payment.state).to eq('prepaid')
        expect(payment.cash_user_id).to eq(user.id)
      end

      it 'redirects back with success notice' do
        post :mark_as_paid, params: { id: payment.id }
        
        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to eq('Oznaczono jako zapłacone')
      end
    end

    context 'when user has events role' do
      let(:user) { create(:user, roles: ['events']) }
      
      before { sign_in(user) }

      it 'marks payment as cash paid' do
        post :mark_as_paid, params: { id: payment.id }
        
        payment.reload
        expect(payment.cash).to be true
        expect(payment.state).to eq('prepaid')
      end
    end

    context 'when user has no permissions' do
      let(:user) { create(:user, roles: []) }
      
      before { sign_in(user) }

      it 'does not mark payment as paid' do
        post :mark_as_paid, params: { id: payment.id }
        
        payment.reload
        expect(payment.cash).to be false
        expect(payment.state).to eq('unpaid')
      end

      it 'redirects back with error' do
        post :mark_as_paid, params: { id: payment.id }
        
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('Nie masz uprawnień')
      end
    end
  end

  describe 'POST #charge' do
    let(:user) { create(:user) }
    let(:service_double) { instance_double(Payments::CreatePayment) }
    
    before do
      sign_in(user)
      allow(Payments::CreatePayment).to receive(:new).with(payment: payment).and_return(service_double)
    end

    context 'when payment creation succeeds' do
      let(:payment_url) { 'https://ssl.dotpay.pl/test_payment/?pid=test123' }
      let(:result) { Success.new(payment_url: payment_url) }
      
      before do
        allow(service_double).to receive(:create).and_return(result)
      end

      it 'updates payment with payment_url' do
        post :charge, params: { id: payment.id }
        
        expect(payment.reload.payment_url).to eq(payment_url)
      end

      it 'redirects to the payment URL' do
        post :charge, params: { id: payment.id }
        
        expect(response).to redirect_to(payment_url)
      end
    end

    context 'when payment URL is invalid' do
      let(:error_message) { 'Invalid payment URL format' }
      let(:result) { Failure.new(:wrong_payment_url, message: error_message) }
      
      before do
        allow(service_double).to receive(:create).and_return(result)
      end

      it 'redirects to root path with alert' do
        post :charge, params: { id: payment.id }
        
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq(error_message)
      end
    end

    context 'when Dotpay request fails' do
      let(:error_message) { 'Dotpay API error occurred' }
      let(:result) { Failure.new(:dotpay_request_error, message: error_message) }
      
      before do
        allow(service_double).to receive(:create).and_return(result)
      end

      it 'redirects to root path with alert' do
        post :charge, params: { id: payment.id }
        
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq(error_message)
      end
    end
  end

  describe 'POST #refund' do
    let(:user) { create(:user, roles: ['events']) }
    let(:get_operation_service) { instance_double(Payments::Dotpay::GetOperationRequest) }
    let(:refund_service) { instance_double(Payments::Dotpay::RefundPaymentRequest) }
    
    before do
      sign_in(user)
      allow(Payments::Dotpay::GetOperationRequest).to receive(:new)
        .with(code: payment.dotpay_id).and_return(get_operation_service)
    end

    context 'when refund succeeds' do
      let(:api_response) { { "results" => [{ "number" => "OP123456" }] }.to_json }
      let(:get_result) { Success.new(api_response) }
      let(:refund_result) { Success.new }
      
      before do
        allow(get_operation_service).to receive(:execute).and_return(get_result)
        allow(Payments::Dotpay::RefundPaymentRequest).to receive(:new)
          .with(code: "OP123456").and_return(refund_service)
        allow(refund_service).to receive(:execute).and_return(refund_result)
      end

      it 'updates payment with refunded_at timestamp' do
        Timecop.freeze do
          post :refund, params: { id: payment.id }
          
          payment.reload
          expect(payment.refunded_at).to be_within(1.second).of(Time.current)
        end
      end

      it 'redirects back with success notice' do
        post :refund, params: { id: payment.id }
        
        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to eq('Zwrócono')
      end
    end

    context 'when no operation found to refund' do
      let(:api_response) { { "results" => [] }.to_json }
      let(:get_result) { Success.new(api_response) }
      
      before do
        allow(get_operation_service).to receive(:execute).and_return(get_result)
      end

      it 'redirects back with error' do
        post :refund, params: { id: payment.id }
        
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('Brak płatności do zwrotu!')
      end
    end

    context 'when get operation request fails' do
      let(:get_result) { Failure.new(:dotpay_request_error) }
      
      before do
        allow(get_operation_service).to receive(:execute).and_return(get_result)
      end

      it 'redirects back with error' do
        post :refund, params: { id: payment.id }
        
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('Błąd podczas zwrotu!')
      end
    end

    context 'when refund request fails' do
      let(:api_response) { { "results" => [{ "number" => "OP123456" }] }.to_json }
      let(:get_result) { Success.new(api_response) }
      let(:refund_result) { Failure.new(:dotpay_request_error) }
      
      before do
        allow(get_operation_service).to receive(:execute).and_return(get_result)
        allow(Payments::Dotpay::RefundPaymentRequest).to receive(:new)
          .with(code: "OP123456").and_return(refund_service)
        allow(refund_service).to receive(:execute).and_return(refund_result)
      end

      it 'redirects back with error' do
        post :refund, params: { id: payment.id }
        
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('Błąd podczas zwrotu!')
      end
    end
  end
end