module Membership
  class FeesReminderService
    def call
      Membership::FeesMailer.yearly_reminder(recipient_emails).deliver_later
    end

    def recipient_emails
      kw_ids = Membership::FeesRepository.new.get_unpaid_kw_ids_this_year
      Db::Profile.where(kw_id: kw_ids).where.not('position @> array[?]', 'honorable_kw').where.not('position @> array[?]', 'senior').map(&:email)
    end
  end
end
