require 'results'

module Reservations
  class CreateReservation
    class << self
      def create(user:, form:)
        return Failure.new(:form_invalid, form: form) unless form.valid?
        return Failure.new(:user_has_to_be_present) unless user.present?

        if (items_reserved_in_period(form.start_date) & form.item_ids.map(&:to_i)).any?
          return Failure.new(:item_already_reserved, form: form)
        end

        reservation = Db::Reservation
          .where(start_date: form.start_date, user_id: user.id)
          .not_prepaid
          .not_cash
          .first_or_initialize(form.attributes)

        if reservation.payment.present? && reservation.payment.paid?
          reservation = Db::Reservation.new(form.attributes)
        end

        reservation.user = user
        items_to_add = (reservation.items + form.items).uniq
        reservation.items = items_to_add
        reservation.save
        reservation.create_payment(dotpay_id: SecureRandom.hex(13))

        Success.new
      end

      def items_reserved_in_period(start_date)
        reserved = Db::Reservation.where(start_date: start_date).map(&:item_ids).flatten
        not_returned = Db::Reservation.holding_until(start_date).map(&:item_ids).flatten

        (reserved + not_returned).uniq
      end
    end
  end
end
