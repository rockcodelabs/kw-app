# frozen_string_literal: true

module Reservations
  class UpdateItemsForm < Dry::Validation::Contract
    params do
      required(:id).filled(:string)
      required(:items_ids).filled(:string)
    end
  end
end
