module Training
  module Supplementary
    class SignUpsController < ApplicationController
      include EitherMatcher
      append_view_path 'app/components'

      def edit
        @sign_up = Training::Supplementary::SignUpRecord.find(params[:id])
        authorize_sign_up_management!(@sign_up.course)
        @limiter = Training::Supplementary::Limiter.new(@sign_up.course)
      end

      def update
        @sign_up = Training::Supplementary::SignUpRecord.find(params[:id])
        authorize_sign_up_management!(@sign_up.course)
        @limiter = Training::Supplementary::Limiter.new(@sign_up.course)
        either(update_record) do |result|
          result.success do
            redirect_back(fallback_location: root_path, notice: 'Zaktualizowałeś!')
          end

          result.failure do |errors|
            flash[:error] = errors.map {|k,v| "#{SignUpRecord.human_attribute_name(k)} #{v.kind_of?(Array) ? v.to_sentence : v}"}.join(', ')
            redirect_back(fallback_location: root_path)
          end
        end
      end

      def manually
        authorize_sign_up_management!(Training::Supplementary::CourseRecord.find(manually_sign_up_params[:course_id]))

        either(manually_sign_up) do |result|
          result.success do
            redirect_back(fallback_location: root_path, notice: 'Zapisałeś uczestnika i wysłałeś link do płatności!')
          end

          result.failure do |errors|
            flash[:error] = errors.map {|k,v| "#{SignUpRecord.human_attribute_name(k)} #{v.kind_of?(Array) ? v.to_sentence : v}"}.join(', ')
            redirect_back(fallback_location: root_path)
          end
        end
      end

      def create
        either(create_record) do |result|
          result.success do
            redirect_back(fallback_location: root_path, notice: 'Zapisałeś się!')
          end

          result.failure do |errors|
            flash[:error] = errors.map {|k,v| "#{SignUpRecord.human_attribute_name(k)} #{v.kind_of?(Array) ? v.to_sentence : v}"}.join(', ')
            redirect_back(fallback_location: root_path)
          end
        end
      end

      def cancel
        sign_up = Training::Supplementary::SignUpRecord.find_by(code: params[:code])
        if sign_up.present?
          sign_up.destroy

          redirect_to polish_event_path(sign_up.course.id), notice: 'Wypisaliśmy Cię z wydarzenia!'
        else
          redirect_to wydarzenia_path, alert: 'Nie znaleziono takiego zapisu, być może już się wypisałeś!'
        end
      end

      def cancel_cash_payment
        if user_signed_in? && (current_user.admin? || current_user.roles.include?('events'))
          sign_up = Training::Supplementary::SignUpRecord.find(params[:id])
          sign_up.payment.update(cash: false, cash_user_id: current_user.id, state: 'unpaid')

          redirect_back(fallback_location: polish_event_path(sign_up.course.id))
        else
          redirect_back(fallback_location: wydarzenia_path, alert: 'Nie masz uprawnień!')
        end
      end

      def send_email
        if user_signed_in? && (current_user.admin? || current_user.roles.include?('events'))
          sign_up = Training::Supplementary::SignUpRecord.find(params[:id])
          expired_at = unless sign_up.course.expired_hours.zero?
            Time.zone.now + sign_up.course.expired_hours.hours
          end
          sign_up.update(expired_at: expired_at)
          Training::Supplementary::SignUpMailer.sign_up(sign_up.id).deliver_later
          sign_up.update(sent_user_id: current_user.id, sent_at: Time.zone.now)

          redirect_to polish_event_path(sign_up.course.id), notice: 'Wysłano e-mail z linkiem do płatności!'
        else
          redirect_back(fallback_location: wydarzenia_path, alert: 'Nie masz uprawnień!')
        end
      end

      def destroy
        if user_signed_in? && (current_user.admin? || current_user.roles.include?('events'))
          sign_up = Training::Supplementary::SignUpRecord.find(params[:id])
          course_id = sign_up.course.id
          if sign_up.present?
            Training::Supplementary::DestroySignUp.new(
              Training::Supplementary::Repository.new
            ).call(id: sign_up.id)
          end

          redirect_to polish_event_path(course_id), notice: 'Usunięto zapis!'
        else
          redirect_back(fallback_location: wydarzenia_path, alert: 'Nie usunięto zapisu!')
        end
      end

      private

      def authorize_sign_up_management!(course)
        return if user_signed_in? && (current_user.admin? || current_user.roles.include?('events') || course.organizator_id == current_user.id)

        raise CanCan::AccessDenied, 'Nie masz uprawnień!'
      end

      def manually_sign_up
        Training::Supplementary::ManuallySignUp.new(
          Training::Supplementary::Repository.new,
          Training::Supplementary::ManuallySignUpForm.new
        ).call(admin_id: current_user&.id, raw_inputs: manually_sign_up_params)
      end

      def create_record
        Training::Supplementary::CreateSignUp.new(
          Training::Supplementary::Repository.new,
          Training::Supplementary::CreateSignUpForm.new
        ).call(raw_inputs: sign_up_params)
      end

      def update_record
        Training::Supplementary::UpdateSignUp.new(
          Training::Supplementary::Repository.new,
          Training::Supplementary::CreateSignUpForm.new
        ).call(id: params[:id], raw_inputs: sign_up_params)
      end

      def manually_sign_up_params
        params.require(:manually_sign_up).permit(:name, :email, :course_id, :supplementary_course_package_type_id, :link_payment)
      end

      def sign_up_params
        params.require(:sign_up).permit(:name, :email, :user_id, :course_id, :supplementary_course_package_type_id, :expired_at, :question)
      end
    end
  end
end
