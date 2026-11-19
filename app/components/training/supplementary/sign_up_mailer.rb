module Training
  module Supplementary
    class SignUpMailer < ApplicationMailer
      append_view_path 'app/components/'

      def prepaid_email(sign_up_id)
        @sign_up = ::Training::Supplementary::SignUpRecord.find(sign_up_id)
        organizer = @sign_up.course.organizer

        mail(
          to: ['wydarzenia@kw.krakow.pl', @sign_up.email, organizer&.email].compact,
          from: 'wydarzenia@kw.krakow.pl',
          subject: "Opłaciłes zapis na wydarzenie KW Kraków: #{@sign_up.course.name}!"
        ).tap do |message|
          message.mailgun_options = {
            "mailable_id" => @sign_up.id,
            "mailable_type" => @sign_up.class.name
          }
        end
      end

      def sign_up(sign_up_id)
        @sign_up = ::Training::Supplementary::SignUpRecord.find(sign_up_id)
        organizer = @sign_up.course.organizer

        mail(
          to: ['wydarzenia@kw.krakow.pl', @sign_up.email, organizer&.email].compact,
          from: 'wydarzenia@kw.krakow.pl',
          subject: "Zapisałeś się na wydarzenie KW Kraków: #{@sign_up.course.name}!"
        ).tap do |message|
          message.mailgun_options = {
            "mailable_id" => @sign_up.id,
            "mailable_type" => @sign_up.class.name
          }
        end
      end

      def deleted_sign_up(course, email)
        @course = course
        mail(
          to: ['wydarzenia@kw.krakow.pl', email],
          from: 'wydarzenia@kw.krakow.pl',
          subject: "Twój czas na płatność za #{@course.name} wygasł!"
        )
      end
    end
  end
end
