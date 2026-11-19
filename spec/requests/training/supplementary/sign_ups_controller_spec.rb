# frozen_string_literal: true

require 'rails_helper'

# Post-deploy critical flow: signing up to a course, the payment record,
# cancelling, and the admin paths (manual sign-up, payment link, cash).
RSpec.describe 'Training::Supplementary::SignUpsController', type: :request do
  let(:member) { create(:user, :with_membership, :with_profile) }
  let(:events_user) { create(:user, :with_events_role, :with_membership, :with_profile) }
  let(:other_member) { create(:user, :with_membership, :with_profile) }

  let!(:course) do
    Training::Supplementary::CourseRecord.create!(
      name: 'Kurs lodowy', place: 'Kraków', state: :published, payment_type: :trainings,
      price_kw: 150, start_date: 2.weeks.from_now, end_date: 2.weeks.from_now + 1.day
    )
  end

  let(:sign_up_params) do
    { sign_up: { name: member.display_name, email: member.email, user_id: member.id.to_s, course_id: course.id.to_s } }
  end

  before { ActiveJob::Base.queue_adapter = :test }

  describe 'POST create' do
    before { sign_in member }

    it 'signs the member up, creates an unpaid payment and enqueues the payment-link mail' do
      expect { post supplementary_sign_ups_path, params: sign_up_params, headers: { 'HTTP_REFERER' => '/wydarzenia' } }
        .to change(Training::Supplementary::SignUpRecord, :count).by(1)
        .and change(Db::Payment, :count).by(1)
        .and have_enqueued_mail(Training::Supplementary::SignUpMailer, :sign_up)

      sign_up = Training::Supplementary::SignUpRecord.last
      expect(sign_up.user).to eq(member)
      expect(sign_up.sent_at).to be_present
      expect(sign_up.payment.state).to eq('unpaid')
      expect(sign_up.payment.dotpay_id).to be_present
      expect(sign_up.payment.payable).to eq(sign_up)
      expect(sign_up.cost).to eq(150)
      expect(flash[:notice]).to eq('Zapisałeś się!')
    end

    it 'sets the expiry when the course expires unpaid sign-ups' do
      course.update!(expired_hours: 24)

      post supplementary_sign_ups_path, params: sign_up_params

      expect(Training::Supplementary::SignUpRecord.last.expired_at).to be_within(1.minute).of(24.hours.from_now)
    end

    it 'does not send the mail when the course sends links manually' do
      course.update!(send_manually: true)

      expect { post supplementary_sign_ups_path, params: sign_up_params }
        .not_to have_enqueued_mail(Training::Supplementary::SignUpMailer, :sign_up)

      expect(Training::Supplementary::SignUpRecord.count).to eq(1)
    end

    it 'rejects a second sign-up with the same email' do
      post supplementary_sign_ups_path, params: sign_up_params

      expect { post supplementary_sign_ups_path, params: sign_up_params }
        .not_to change(Training::Supplementary::SignUpRecord, :count)

      expect(flash[:error]).to be_present
    end

    it 'requires an answer when the course asks a question' do
      course.update!(question: true)

      expect { post supplementary_sign_ups_path, params: sign_up_params }
        .not_to change(Training::Supplementary::SignUpRecord, :count)

      expect(flash[:error]).to be_present
    end

    it 'requires a package when the course has packages' do
      course.update!(packages: true)

      expect { post supplementary_sign_ups_path, params: sign_up_params }
        .not_to change(Training::Supplementary::SignUpRecord, :count)

      expect(flash[:error]).to be_present
    end

    it 'prices the sign-up from the chosen package' do
      course.update!(packages: true)
      package = course.package_types.create!(name: 'Pakiet', cost: 99)
      params = sign_up_params.deep_merge(sign_up: { supplementary_course_package_type_id: package.id.to_s })

      post supplementary_sign_ups_path, params: params

      expect(Training::Supplementary::SignUpRecord.last.cost).to eq(99)
    end

    it 'lets a guest sign up with name and email only' do
      sign_out member

      expect do
        post supplementary_sign_ups_path,
          params: { sign_up: { name: 'Gość', email: 'gosc@example.com', course_id: course.id.to_s } }
      end.to change(Training::Supplementary::SignUpRecord, :count).by(1)

      expect(Training::Supplementary::SignUpRecord.last.user_id).to be_nil
    end
  end

  describe 'GET cancel (public link from the e-mail)' do
    let!(:sign_up) do
      Training::Supplementary::Repository.new.sign_up!(
        name: 'Gość', email: 'gosc@example.com', user_id: nil, course_id: course.id, question: nil
      )
    end

    it 'removes the sign-up and its payment' do
      expect { get polish_event_cancel_path(code: sign_up.code) }
        .to change(Training::Supplementary::SignUpRecord, :count).by(-1)
        .and change(Db::Payment, :count).by(-1)

      expect(response).to have_http_status(:redirect)
      expect(flash[:notice]).to eq('Wypisaliśmy Cię z wydarzenia!')
    end

    it 'redirects to /wydarzenia with an alert for an unknown code' do
      get polish_event_cancel_path(code: 'nope')

      expect(response).to redirect_to(wydarzenia_path)
      expect(flash[:alert]).to be_present
    end
  end

  describe 'events-role admin paths' do
    let!(:sign_up) do
      Training::Supplementary::Repository.new.sign_up!(
        name: 'Gość', email: 'gosc@example.com', user_id: nil, course_id: course.id, question: nil
      )
    end

    before { sign_in events_user }

    it 'signs a participant up manually and enqueues the payment link' do
      expect do
        put manually_supplementary_sign_ups_path,
          params: { manually_sign_up: { name: 'Nowy', email: 'nowy@example.com', course_id: course.id.to_s, link_payment: '1' } },
          headers: { 'HTTP_REFERER' => '/wydarzenia' }
      end.to change(Training::Supplementary::SignUpRecord, :count).by(1)
        .and have_enqueued_mail(Training::Supplementary::SignUpMailer, :sign_up)

      created = Training::Supplementary::SignUpRecord.find_by(email: 'nowy@example.com')
      expect(created.admin_id).to eq(events_user.id)
      expect(created.payment.state).to eq('unpaid')
    end

    it 'sends the payment-link mail and stamps the sender' do
      expect { put send_email_supplementary_sign_up_path(sign_up) }
        .to have_enqueued_mail(Training::Supplementary::SignUpMailer, :sign_up)

      expect(sign_up.reload.sent_user_id).to eq(events_user.id)
      expect(sign_up.sent_at).to be_present
    end

    it 'cancels a cash payment back to unpaid' do
      sign_up.payment.update!(cash: true, state: 'prepaid', cash_user_id: events_user.id)

      put cancel_cash_payment_supplementary_sign_up_path(sign_up)

      payment = sign_up.payment.reload
      expect(payment.cash).to be(false)
      expect(payment.state).to eq('unpaid')
      expect(payment.cash_user_id).to eq(events_user.id)
    end

    it 'destroys a sign-up with its payment' do
      expect { delete supplementary_sign_up_path(sign_up) }
        .to change(Training::Supplementary::SignUpRecord, :count).by(-1)
        .and change(Db::Payment, :count).by(-1)

      expect(flash[:notice]).to eq('Usunięto zapis!')
    end
  end

  describe 'authorization of the admin paths' do
    let!(:sign_up) do
      Training::Supplementary::Repository.new.sign_up!(
        name: 'Gość', email: 'gosc@example.com', user_id: nil, course_id: course.id, question: nil
      )
    end

    before { sign_in other_member }

    it 'does not let a plain member send the payment-link mail' do
      expect { put send_email_supplementary_sign_up_path(sign_up) }
        .not_to have_enqueued_mail(Training::Supplementary::SignUpMailer, :sign_up)

      expect(response).to have_http_status(:redirect)
    end

    it 'does not let a plain member cancel a cash payment' do
      sign_up.payment.update!(cash: true, state: 'prepaid')

      put cancel_cash_payment_supplementary_sign_up_path(sign_up)

      expect(sign_up.payment.reload.cash).to be(true)
      expect(response).to have_http_status(:redirect)
    end

    it 'does not let a plain member destroy a sign-up' do
      expect { delete supplementary_sign_up_path(sign_up) }
        .not_to change(Training::Supplementary::SignUpRecord, :count)

      expect(response).to have_http_status(:redirect)
    end

    it 'does not let a plain member sign somebody up manually' do
      expect do
        put manually_supplementary_sign_ups_path,
          params: { manually_sign_up: { name: 'Obcy', email: 'obcy@example.com', course_id: course.id.to_s, link_payment: '1' } }
      end.not_to change(Training::Supplementary::SignUpRecord, :count)
    end

    it "does not let a plain member change somebody else's sign-up" do
      put supplementary_sign_up_path(sign_up),
        params: { sign_up: { name: 'Zmienione', email: 'zmienione@example.com', course_id: course.id.to_s } }

      expect(sign_up.reload.email).to eq('gosc@example.com')
    end

    it 'does not let a plain member open the edit form of a sign-up' do
      get edit_supplementary_sign_up_path(sign_up)

      expect(response).to have_http_status(:redirect)
    end

    it 'does not let anonymous visitors change, destroy or manage sign-ups' do
      sign_out other_member

      put supplementary_sign_up_path(sign_up), params: { sign_up: { name: 'X', email: 'x@example.com', course_id: course.id.to_s } }
      expect(sign_up.reload.email).to eq('gosc@example.com')

      expect { delete supplementary_sign_up_path(sign_up) }.not_to change(Training::Supplementary::SignUpRecord, :count)
      expect { put send_email_supplementary_sign_up_path(sign_up) }
        .not_to have_enqueued_mail(Training::Supplementary::SignUpMailer, :sign_up)
      expect(response).to have_http_status(:redirect)
    end

    context 'when the user organises the course' do
      before { course.update!(organizator_id: other_member.id) }

      it 'lets them sign a participant up manually' do
        expect do
          put manually_supplementary_sign_ups_path,
            params: { manually_sign_up: { name: 'Obcy', email: 'obcy@example.com', course_id: course.id.to_s, link_payment: '1' } }
        end.to change(Training::Supplementary::SignUpRecord, :count).by(1)
      end

      it 'lets them edit a sign-up of their own course' do
        put supplementary_sign_up_path(sign_up),
          params: { sign_up: { name: 'Zmienione', email: 'zmienione@example.com', course_id: course.id.to_s } }

        expect(sign_up.reload.email).to eq('zmienione@example.com')
      end

      it 'does not let them touch sign-ups of a course they do not organise' do
        elsewhere = Training::Supplementary::CourseRecord.create!(name: 'Inny', place: 'X', state: :published, payment_type: :trainings)
        foreign = Training::Supplementary::Repository.new
          .sign_up!(name: 'Obcy', email: 'obcy2@example.com', user_id: nil, course_id: elsewhere.id, question: nil)

        put supplementary_sign_up_path(foreign), params: { sign_up: { name: 'Z', email: 'z@example.com', course_id: elsewhere.id.to_s } }

        expect(foreign.reload.email).to eq('obcy2@example.com')
      end
    end
  end
end
