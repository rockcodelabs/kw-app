module Training
  module Supplementary
    class FillEmptyPlaces
      include Dry::Monads[:result]

      def initialize(repository)
        @repository = repository
      end

      def call(course_id:)
        repository.sign_ups_on_hold(course_id).each do |sign_up|
          if in_limit?(sign_up)
            return Failure(payment: I18n.t('.not_found')) unless sign_up.payment.present?
            Training::Supplementary::SendEmailWithPayment.new(repository).call(id: sign_up.id)
          end
        end

        Success(:success)
      end

      # Read-only: the sign ups on hold that fit the limit right now (what #call would mail, as an upper
      # bound: #call re-checks the limit after each mail it sends).
      def candidates(course_id:)
        repository.sign_ups_on_hold(course_id).select { |sign_up| in_limit?(sign_up) }
      end

      private

      attr_reader :repository

      def in_limit?(sign_up)
        Training::Supplementary::Limiter.new(sign_up.course).in_limit?(sign_up)
      end
    end
  end
end
