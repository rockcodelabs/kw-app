# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Training::Supplementary::UpdateSignUp do
  subject(:service) { described_class.new(Training::Supplementary::Repository.new, Training::Supplementary::CreateSignUpForm.new) }

  let!(:course) { Training::Supplementary::CourseRecord.create!(name: 'Kurs', place: 'Kraków', state: :published) }
  let!(:sign_up) { Training::Supplementary::SignUpRecord.create!(course_id: course.id, name: 'Jan', email: 'jan@example.com') }

  it 'updates the sign up' do
    result = service.call(id: sign_up.id, raw_inputs: { name: 'Nowe', email: 'nowy@example.com', course_id: course.id.to_s })

    expect(result).to be_success
    expect(sign_up.reload).to have_attributes(name: 'Nowe', email: 'nowy@example.com')
  end

  it 'syncs name and e-mail from the linked user' do
    user = create(:user, :with_profile)
    sign_up.update!(user_id: user.id)

    service.call(id: sign_up.id, raw_inputs: { name: 'X', email: 'x@example.com', course_id: course.id.to_s })

    expect(sign_up.reload).to have_attributes(name: user.display_name, email: user.email)
  end

  it 'returns Polish errors and leaves the record unchanged when invalid' do
    result = service.call(id: sign_up.id, raw_inputs: { name: '', email: 'x@example.com', course_id: course.id.to_s })

    expect(result).to be_failure
    expect(result.failure[:name]).to eq(['musi być wypełnione'])
    expect(sign_up.reload.name).to eq('Jan')
  end

  it 'raises for an unknown record' do
    expect { service.call(id: 0, raw_inputs: { name: 'X', email: 'x@example.com', course_id: course.id.to_s }) }
      .to raise_error(ActiveRecord::RecordNotFound)
  end
end
