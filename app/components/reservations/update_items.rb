# frozen_string_literal: true

module Reservations
  class UpdateItems
    include Dry::Monads[:result]

    def initialize(form)
      @form = form
    end

    def call(raw_inputs:)
      form_outputs = form.call(raw_inputs.to_h)

      return Failure(form_outputs.errors(full: true, locale: :pl).to_h) unless form_outputs.success?

      reservation = Db::Reservation.find(form_outputs[:id])
      items_ids = form_outputs[:items_ids].split(' ')
      items = Db::Item.where(rentable_id: items_ids)

      return Failure(items: 'Rezerwacja musi mieć jakieś przedmioty!') unless items.any?

      reservation.items = items
      reservation.save

      Success(:success)
    end

    private

    attr_reader :form
  end
end
