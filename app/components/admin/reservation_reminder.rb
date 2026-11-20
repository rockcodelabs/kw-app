module Admin
  class ReservationReminder
    def self.candidates
      Db::Reservation.expire_tomorrow
    end

    def self.send_reminders
      candidates.each do |reservation|
        ReservationMailer.remind(reservation).deliver_later
      end
    end
  end
end
