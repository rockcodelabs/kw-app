module UserManagement
  module Workers
    class SetRegularsWorker
      include Sidekiq::Worker

      def self.candidates
        Db::Profile.ransack(position_not_cont: 'regular', application_date_lteq: 1.year.ago).result
      end

      def perform(**)
        self.class.candidates.find_each do |p|
          p.position.push('regular').uniq
          p.position.delete('candidate')
          p.save
        end
      end
    end
  end
end
