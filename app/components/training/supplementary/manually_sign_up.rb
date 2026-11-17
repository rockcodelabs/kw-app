# frozen_string_literal: true

module Training
  module Supplementary
    class ManuallySignUp
      include Dry::Monads[:result]

      def initialize(repository, form)
        @repository = repository
        @form = form
      end

      def call(admin_id:, raw_inputs:)
        form_outputs = form.call(raw_inputs.to_h)
        return Failure(form_outputs.errors(locale: :pl).to_h) unless form_outputs.success?

        course = Training::Supplementary::CourseRecord.find(form_outputs[:course_id])
        if form_outputs[:email].present?
          user = ::Db::User.find_by(email: form_outputs[:email])
          if user.nil?
          else
            fee = ::Db::Membership::Fee.find_by(kw_id: user.kw_id, year: Date.today.year)

            if course.last_fee_paid
              return Failure(fee: I18n.t('.not_last_fee')) unless Membership::Activement.new(user: user).active?
            end
          end
        end
        return Failure(email: I18n.t('.email_not_unique')) if Training::Supplementary::SignUpRecord.exists?(course_id: form_outputs[:course_id], email: form_outputs[:email])
        user = ::Db::User.find_by(email: form_outputs[:email])
        if user.nil?
          sign_up = repository.sign_up!(
            course_id: form_outputs[:course_id],
            email: form_outputs[:email],
            user_id: nil,
            name: form_outputs[:name],
            question: nil
          )
        else
          sign_up = repository.sign_up!(
            course_id: form_outputs[:course_id],
            email: form_outputs[:email],
            user_id: user.id,
            name: user.display_name,
            question: nil
          )
        end

        if ActiveModel::Type::Boolean.new.cast(form_outputs[:link_payment])
          if course.packages
            sign_up.update(sent_user_id: admin_id, sent_at: Time.zone.now, admin_id: admin_id, supplementary_course_package_type_id: form_outputs[:supplementary_course_package_type_id])
          else
            sign_up.update(sent_user_id: admin_id, sent_at: Time.zone.now, admin_id: admin_id)
          end
          Training::Supplementary::SignUpMailer.sign_up(sign_up.id).deliver_later
        end
        Success(:success)
      end

      private

      attr_reader :repository, :form
    end
  end
end
