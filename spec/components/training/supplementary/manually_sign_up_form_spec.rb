# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Training::Supplementary::ManuallySignUpForm do
  subject(:form) { described_class.new }

  let(:params) { { email: 'jan@example.com', link_payment: '1', course_id: '1' } }

  it 'accepts the required params' do
    expect(form.call(params)).to be_success
  end

  it 'keeps the optional name and package id' do
    result = form.call(params.merge(name: 'Jan', supplementary_course_package_type_id: '3'))

    expect(result.to_h).to include(name: 'Jan', supplementary_course_package_type_id: '3')
  end

  %i[email link_payment course_id].each do |key|
    it "requires #{key}" do
      expect(form.call(params.merge(key => '')).errors.to_h).to have_key(key)
    end
  end
end
