# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Training::Supplementary::CreateSignUp do
  let(:repository) { Training::Supplementary::Repository.new }
  let(:form) { Training::Supplementary::CreateSignUpForm.new }
  let(:service) { described_class.new(repository, form) }

  describe '#call' do
    context 'when form validation fails' do
      it 'returns Failure with validation errors when required fields are missing' do
        result = service.call(raw_inputs: { course_id: '', email: '', name: '' })

        expect(result).to be_failure

        errors = result.failure
        expect(errors).to be_a(Hash)
        expect(errors.keys).to include(:name, :email, :course_id)
        expect(errors[:name]).to include('musi być wypełnione')
        expect(errors[:email]).to include('musi być wypełnione')
        expect(errors[:course_id]).to include('musi być wypełnione')
      end

      it 'returns Failure with validation errors when fields are blank' do
        result = service.call(raw_inputs: { course_id: '', email: '', name: '', question: '' })

        expect(result).to be_failure
        expect(result.failure).to be_a(Hash)
        expect(result.failure).not_to be_empty
      end
    end
  end
end
