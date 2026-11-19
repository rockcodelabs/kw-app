# frozen_string_literal: true

require 'rails_helper'

# Rendering the mails for real: a request spec only checks that a job was enqueued, so a broken template or a
# nil organizer would stay invisible until a member signs up in production.
RSpec.describe Training::Supplementary::SignUpMailer, type: :mailer do
  let(:organizer) { create(:user, :with_events_role) }
  let(:course) do
    Training::Supplementary::CourseRecord.create!(
      name: 'Kurs lodowy', place: 'Kraków', state: :published, payment_type: :trainings, price: true, price_kw: 150,
      organizator_id: organizer.id, start_date: Time.zone.local(2030, 3, 1, 9, 0)
    )
  end
  let(:sign_up) do
    Training::Supplementary::Repository.new.sign_up!(
      name: 'Jan Kowalski', email: 'jan@example.com', user_id: nil, course_id: course.id, question: nil
    )
  end

  describe '#sign_up' do
    subject(:mail) { described_class.sign_up(sign_up.id) }

    it 'goes to the participant, the organizer and the events mailbox' do
      expect(mail.to).to contain_exactly('wydarzenia@kw.krakow.pl', 'jan@example.com', organizer.email)
      expect(mail.from).to eq(['wydarzenia@kw.krakow.pl'])
    end

    it 'names the course in the subject' do
      expect(mail.subject).to eq('Zapisałeś się na wydarzenie KW Kraków: Kurs lodowy!')
    end

    it 'describes the event and links to the Dotpay charge page of this payment' do
      body = mail.body.encoded

      expect(body).to include('Kurs lodowy', 'Kraków', '01/03/2030 09:00', '150')
      expect(body).to include("/payments/#{sign_up.payment.id}/charge")
    end

    it 'shows the payment deadline when unpaid sign-ups expire' do
      course.update!(expired_hours: 24)
      sign_up.update!(expired_at: Time.zone.local(2030, 2, 1, 12, 30))

      expect(mail.body.encoded).to include('01/02/2030 12:30')
    end

    it 'asks for no online payment when the course is paid in cash' do
      course.update!(cash: true)

      expect(mail.body.encoded).not_to include('/charge')
      expect(mail.body.encoded).to include('Poniżej znajdą się informacje')
    end

    it 'shows the package name and cost for a course with packages' do
      course.update!(packages: true)
      package = course.package_types.create!(name: 'Pakiet VIP', cost: 99)
      sign_up.update!(supplementary_course_package_type_id: package.id)

      expect(mail.body.encoded).to include('Pakiet VIP - 99 zł')
    end

    it 'includes the organizer remarks' do
      course.update!(email_remarks: 'Zabierz raki')

      expect(mail.body.encoded).to include('Zabierz raki')
    end

    it 'tags the message for the Mailgun delivery webhook' do
      expect(mail.mailgun_options).to include('mailable_id' => sign_up.id, 'mailable_type' => 'Training::Supplementary::SignUpRecord')
    end

    it 'renders without an organizer', pending: 'G29: a course without organizator_id makes the mailer raise RecordNotFound' do
      course.update_column(:organizator_id, nil)

      expect { mail.body.encoded }.not_to raise_error
    end

    it 'renders for a course with packages when the sign-up has no package yet', pending: 'G29: package_type is nil' do
      course.update!(packages: true)

      expect { mail.body.encoded }.not_to raise_error
    end
  end

  describe '#prepaid_email' do
    subject(:mail) { described_class.prepaid_email(sign_up.id) }

    it 'confirms the payment to the participant, organizer and events mailbox' do
      expect(mail.to).to contain_exactly('wydarzenia@kw.krakow.pl', 'jan@example.com', organizer.email)
      expect(mail.subject).to eq('Opłaciłes zapis na wydarzenie KW Kraków: Kurs lodowy!')
    end

    it 'renders the event data and the paid-mail remarks' do
      course.update!(paid_email: 'Zbiórka o 8:00')

      expect(mail.body.encoded).to include('Kurs lodowy', 'Zbiórka o 8:00', organizer.display_name)
    end
  end

  describe '#deleted_sign_up' do
    subject(:mail) { described_class.deleted_sign_up(course, 'jan@example.com') }

    it 'tells the participant the payment time expired and links back to the event' do
      expect(mail.to).to contain_exactly('wydarzenia@kw.krakow.pl', 'jan@example.com')
      expect(mail.subject).to eq('Twój czas na płatność za Kurs lodowy wygasł!')
      expect(mail.body.encoded).to include("/wydarzenia/#{course.slug}")
    end
  end
end
