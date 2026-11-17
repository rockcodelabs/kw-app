# frozen_string_literal: true

module Training
  module Supplementary
    class CreateSignUp
      include Dry::Monads[:result]

      def initialize(repository, form)
        @repository = repository
        @form = form
      end

      def call(raw_inputs:)
        form_outputs = form.call(raw_inputs.to_h)
        return Failure(form_outputs.errors(locale: :pl).to_h) unless form_outputs.success?

        course = Training::Supplementary::CourseRecord.find(form_outputs[:course_id])
        return Failure(email: I18n.t('.email_not_unique')) if Training::Supplementary::SignUpRecord.exists?(course_id: form_outputs[:course_id], email: form_outputs[:email])
        if form_outputs[:user_id].present?
          user = ::Db::User.find(form_outputs[:user_id])
          fee = ::Db::Membership::Fee.find_by(kw_id: user.kw_id, year: Date.today.year)

          if course.last_fee_paid
            return Failure(fee: I18n.t('.not_last_fee')) unless Membership::Activement.new(user: user).supplementary_training_active?
          end

          if course.packages
            package = Training::Supplementary::PackageTypeRecord.find(form_outputs[:supplementary_course_package_type_id])

            if package.membership
              return Failure(fee: I18n.t('.not_last_fee')) unless Membership::Activement.new(user: user).supplementary_training_active?
            end
          end

          sign_up = repository.sign_up!(
            course_id: form_outputs[:course_id],
            email: form_outputs[:email],
            name: form_outputs[:name],
            user_id: form_outputs[:user_id],
            question: form_outputs[:question]
          )
        else
          if course.packages
            package = Training::Supplementary::PackageTypeRecord.find(form_outputs[:supplementary_course_package_type_id])

            if package.membership
              return Failure(fee: I18n.t('.not_last_fee'))
            end
          end

          sign_up = repository.sign_up!(
            course_id: form_outputs[:course_id],
            email: form_outputs[:email],
            name: form_outputs[:name],
            user_id: nil,
            question: form_outputs[:question]
          )
        end
        sign_up.update(supplementary_course_package_type_id: form_outputs[:supplementary_course_package_type_id]) if course.packages
        if !course.send_manually && Training::Supplementary::Limiter.new(course).in_limit?(sign_up)
          expired_at = unless course.expired_hours.zero?
            Time.zone.now + course.expired_hours.hours
          end
          sign_up.update(expired_at: expired_at)
          Training::Supplementary::SignUpMailer.sign_up(sign_up.id).deliver_later
          sign_up.update(sent_at: Time.zone.now)
        end
        Success(:success)
      end

      private

      attr_reader :repository, :form
    end
  end
end
