module Training
  module Supplementary
    class SendEmailWithPayment
      include Dry::Monads[:result]

      def initialize(repository)
        @repository = repository
      end

      def call(id:)
        sign_up = repository.find_sign_up(id)
        return Failure(email: I18n.t('.not_found')) unless sign_up.present?
        return Failure(payment: I18n.t('.not_found')) unless sign_up.payment.present?

        expired_at = unless sign_up.course.expired_hours.zero?
          Time.zone.now + sign_up.course.expired_hours.hours
        end
        sign_up.update(expired_at: expired_at)
        ::Training::Supplementary::SignUpMailer.sign_up(sign_up.id).deliver_later
        sign_up.update(sent_at: Time.zone.now)

        Success(:success)
      end

      private

      attr_reader :repository
    end
  end
end
