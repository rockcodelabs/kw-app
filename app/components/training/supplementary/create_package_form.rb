# frozen_string_literal: true

module Training
  module Supplementary
    class CreatePackageForm < Dry::Validation::Contract
      params do
        required(:name).filled(:string)
        required(:cost).filled
        required(:course_id).filled
        optional(:membership)
      end
    end
  end
end
