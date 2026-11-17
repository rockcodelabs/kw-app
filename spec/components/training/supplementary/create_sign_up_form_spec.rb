# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Training::Supplementary::CreateSignUpForm do
  subject(:form) { described_class.new }

  let!(:course) { Training::Supplementary::CourseRecord.create!(name: 'Kurs', place: 'Kraków', state: :published) }
  let(:params) { { name: 'Jan', email: 'jan@example.com', course_id: course.id.to_s } }

  it 'accepts the minimal params' do
    expect(form.call(params)).to be_success
  end

  %i[name email course_id].each do |key|
    it "requires #{key}" do
      expect(form.call(params.merge(key => '')).errors.to_h).to have_key(key)
    end
  end

  context 'when the course asks a question' do
    before { course.update!(question: true) }

    it 'requires an answer' do
      result = form.call(params)

      expect(result.errors(locale: :pl).to_h[:question]).to eq(['musi zostać wypełniona!'])
    end

    it 'passes with an answer' do
      expect(form.call(params.merge(question: 'Tak'))).to be_success
    end
  end

  context 'when the course has packages' do
    before { course.update!(packages: true) }

    it 'requires a package' do
      expect(form.call(params).errors.to_h).to have_key(:supplementary_course_package_type_id)
    end

    it 'passes with a package id' do
      expect(form.call(params.merge(supplementary_course_package_type_id: '1'))).to be_success
    end
  end

  it 'does not fail for an unknown course in the rules' do
    expect { form.call(params.merge(course_id: '0')) }.not_to raise_error
  end
end
