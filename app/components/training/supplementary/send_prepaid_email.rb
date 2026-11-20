module Training
  module Supplementary
    class SendPrepaidEmail
      def send_prepaid_emails
        candidates.map(&:id).each do |sign_up_id|
          Training::Supplementary::Workers::SendPrepaidEmailsWorker.perform_async(sign_up_id)
        end
      end

      def candidates
        Training::Supplementary::Repository.new.prepaid_not_emailed_sign_ups
      end
    end
  end
end
