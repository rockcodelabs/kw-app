module Events
  module Competitions
    class Repository
      def find_sign_up(id)
        Events::Db::SignUpRecord.find_by(id: id)
      end

      def create(form_outputs:)
        record = Events::Db::CompetitionRecord.create!(form_outputs.to_h)
        record.package_types.create(name: 'KW', cost: 30)
        record.package_types.create(name: 'poza KW', cost: 60)
        Events::Competition.from_record(record)
      end

      def update(id:, form_outputs:)
        record = Events::Db::CompetitionRecord.find_by(id: id)
        record.update(form_outputs.to_h)
        Events::Competition.from_record(record)
      end

      def create_sign_up(competition_id:, form_outputs:)
        attributes = form_outputs
          .to_h.tap { |hs| hs.delete(:terms_of_service) }.merge(competition_record_id: competition_id)
        record = Events::Db::SignUpRecord.create!(attributes)
        record.create_payment(dotpay_id: SecureRandom.hex(13))
        record
      end

      def update_sign_up(sign_up_record_id:, form_outputs:)
        attributes = form_outputs
          .to_h.tap { |hs| hs.delete(:terms_of_service) }
        record = Events::Db::SignUpRecord.find(sign_up_record_id)
        record.update(attributes)
        record
      end

      def expired_sign_ups
        Events::Db::SignUpRecord
          .joins(:payment)
          .where.not(sent_at: nil)
          .where.not(expired_at: nil)
          .where('expired_at < ?', Time.zone.now)
          .where(payments: { state: 'unpaid' })
      end
    end
  end
end
