# frozen_string_literal: true

module Training
  module Supplementary
    class CreateSignUpForm < Dry::Validation::Contract
      config.messages.load_paths << 'app/components/training/errors.yml'

      params do
        required(:name).filled(:string)
        required(:email).filled(:string)
        required(:course_id).filled(:string)
        optional(:supplementary_course_package_type_id).maybe(:string)
        optional(:user_id)
        optional(:question).maybe(:string)
        optional(:expired_at)
      end

      rule(:question, :course_id) do
        course = Training::Supplementary::CourseRecord.find_by(id: values[:course_id])
        key(:question).failure(:question_required) if course&.question && values[:question].blank?
      end

      rule(:supplementary_course_package_type_id, :course_id) do
        course = Training::Supplementary::CourseRecord.find_by(id: values[:course_id])
        key(:supplementary_course_package_type_id).failure(:package_required) if course&.packages && values[:supplementary_course_package_type_id].blank?
      end
    end
  end
end
