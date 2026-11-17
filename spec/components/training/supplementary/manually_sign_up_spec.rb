# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Training::Supplementary::ManuallySignUp do
  subject(:service) { described_class.new(Training::Supplementary::Repository.new, Training::Supplementary::ManuallySignUpForm.new) }

  let(:admin) { create(:user, :admin) }
  let!(:course) { Training::Supplementary::CourseRecord.create!(name: 'Kurs', place: 'Kraków', state: :published, send_manually: true) }
  let(:inputs) { { email: 'jan@example.com', name: 'Jan Kowalski', link_payment: '0', course_id: course.id.to_s } }

  before { ActiveJob::Base.queue_adapter = :test }

  def call(overrides = {})
    service.call(admin_id: admin.id, raw_inputs: inputs.merge(overrides))
  end

  it 'signs up a person without an account' do
    expect { expect(call).to be_success }.to change(Training::Supplementary::SignUpRecord, :count).by(1)

    expect(Training::Supplementary::SignUpRecord.last).to have_attributes(email: 'jan@example.com', name: 'Jan Kowalski', user_id: nil)
  end

  it 'links an existing user and uses the display name' do
    user = create(:user, :with_profile)

    call(email: user.email)

    expect(Training::Supplementary::SignUpRecord.last).to have_attributes(user_id: user.id, name: user.display_name)
  end

  it 'marks the sign up as sent by the admin and mails the payment link' do
    expect { call(link_payment: '1') }.to have_enqueued_mail(Training::Supplementary::SignUpMailer, :sign_up)

    expect(Training::Supplementary::SignUpRecord.last).to have_attributes(admin_id: admin.id, sent_user_id: admin.id)
  end

  it 'does not mail without the payment link flag' do
    expect { call }.not_to have_enqueued_mail
  end

  it 'rejects a duplicate sign up' do
    call

    result = call
    expect(result).to be_failure
    expect(result.failure).to have_key(:email)
  end

  it 'returns Polish validation errors' do
    result = call(email: '')

    expect(result).to be_failure
    expect(result.failure[:email]).to eq(['musi być wypełnione'])
  end
end
