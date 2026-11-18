module Management
  module Voting
    class Reminder
      def self.send_reminders
        Management::Voting::CaseRecord.where(state: 'voting').each do |case_record|
          Management::Voting::Repository.new.missing_votes_on(case_record.id).each do |user|
            if case_record.created_at <= 3.days.ago
              Management::Voting::Mailer.notify(case_record.id, user.id).deliver_later
            end
          end
        end
      end

      def self.close_outdated
        Management::Voting::CaseRecord.where(state: 'voting').each do |case_record|
          if case_record.created_at <= 7.days.ago
            case_record.finish!
          end
        end
      end
    end
  end
end
