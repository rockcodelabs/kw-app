module Business
  class Repository
    def expired_sign_ups
      expired = ::Business::SignUpRecord
        .where.not(sent_at: nil)
        .where.not(expired_at: nil)
        .where('expired_at < ?', Time.zone.now)

      end_unpaid = expired.select do |sign_up|
        sign_up.first_payment.unpaid?
      end
      end_unpaid
    end

    def sign_ups_for_equipment
      ::Business::SignUpRecord
        .joins(:payments)
        .where(equipment_at: nil, payments: { state: 'prepaid' })
    end
  end
end
