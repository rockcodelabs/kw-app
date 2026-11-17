# frozen_string_literal: true

module Training
  module Supplementary
    class ManuallySignUpForm < Dry::Validation::Contract
      params do
        required(:email).filled(:string)
        required(:link_payment).filled
        required(:course_id).filled(:string)
        optional(:name).maybe(:string)
        optional(:supplementary_course_package_type_id).maybe(:string)
      end
    end
  end
end
