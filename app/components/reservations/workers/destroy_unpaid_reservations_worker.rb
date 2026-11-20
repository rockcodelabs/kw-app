module Reservations
  module Workers
    class DestroyUnpaidReservationsWorker
      include Sidekiq::Worker

      def self.candidates
        not_prepaid = Db::Reservation.where('reservations.created_at < ?', 2.day.ago)
                                    .not_prepaid
        prepaid_by_cash = Db::Reservation.where('reservations.created_at < ?', 2.day.ago)
                                        .cash_prepaid
        not_prepaid - prepaid_by_cash
      end

      def perform(**)
        self.class.candidates.map(&:destroy)
      end
    end
  end
end
