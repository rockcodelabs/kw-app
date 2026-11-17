class ProfileMailer < ApplicationMailer
  def accepted(profile)
    @profile = profile
    @setting = Management::SettingsRecord.find_by(path: "zgloszenie/accepted/#{@profile.locale}")
    @last_5_events = Training::Supplementary::CourseRecord.all.limit(5)

    I18n.with_locale(@profile.locale) do
      mail(
        to: @profile.email,
        from: 'zgloszenia@kw.krakow.pl',
        subject: I18n.t('profile_mailer.accepted.subject', first_name: @profile.first_name, last_name: @profile.last_name)
      ).tap do |message|
        message.mailgun_options = {
          "mailable_id" => @profile.id,
          "mailable_type" => @profile.class.name
        }
      end
    end
  end

  def list(profile)
    @profile = profile
    @setting = Management::SettingsRecord.find_by(path: "zgloszenie/list/#{@profile.locale}")

    I18n.with_locale(@profile.locale) do
      mail(
        to: [@profile.email, 'zgloszenia.wykaz@kw.krakow.pl'],
        from: 'zgloszenia@kw.krakow.pl',
        subject: I18n.t('profile_mailer.list.subject', first_name: @profile.first_name, last_name: @profile.last_name)
      ).tap do |message|
        message.mailgun_options = {
          "mailable_id" => @profile.id,
          "mailable_type" => @profile.class.name
        }
      end
    end
  end

  def apply(profile)
    @profile = profile
    @setting = Management::SettingsRecord.find_by(path: "zgloszenie/apply/#{@profile.locale}")

    pdf = Prawn::Document.new
    pdf.define_grid(columns: 3, rows: 10, gutter: 0)
   #pdf.grid(0,0).bounding_box do
   #  pdf.image "#{Rails.root}/app/assets/images/kw-logo.png", position: :center, scale: 0.18
   #end
   #pdf.grid(0,1).bounding_box do
   #  pdf.image "#{Rails.root}/app/assets/images/opp-logo.png", position: :center, scale: 0.1
   #end
   #pdf.grid(0,2).bounding_box do
   #  pdf.image "#{Rails.root}/app/assets/images/pza-logo.png", position: :center, scale: 0.2
   #end
    pdf.grid([1,0], [1,2]).bounding_box do
      pdf.stroke_horizontal_rule
      pdf.move_down 5
      pdf.font "#{Rails.root}/app/assets/fonts/Roboto-Bold.ttf" do
        pdf.text 'Deklaracja członkowska', align: :center
      end
      pdf.move_down 12
      pdf.font "#{Rails.root}/app/assets/fonts/Roboto-Regular.ttf" do
        pdf.text 'Proszę o przyjęcie mnie w poczet członków zwyczajnych Klubu Wysokogórskiego Kraków.', align: :left, size: 8
        pdf.move_down 5
        pdf.text "Imię i Nazwisko: #{@profile.first_name} #{@profile.last_name}", align: :left, size: 9
      end
    end
    pdf.grid([2,0], [2,2]).bounding_box do
      pdf.font "#{Rails.root}/app/assets/fonts/Roboto-Regular.ttf" do
        pdf.text "Data i miejsce urodzenia: #{@profile.birth_date}, #{@profile.birth_place}", align: :left, size: 9
        pdf.move_down 3
        pdf.text "Adres zamieszkania: #{@profile.optional_address}, #{@profile.postal_code}, #{@profile.city}", align: :left, size: 9
        pdf.move_down 3
        pdf.text "Numer telefonu: #{@profile.phone}", align: :left, size: 9
        pdf.move_down 3
        pdf.text "Adres email: #{@profile.email}", align: :left, size: 9
        pdf.move_down 3
      end
    end
    pdf.grid([3,0], [3,2]).bounding_box do
      pdf.font "#{Rails.root}/app/assets/fonts/Roboto-Regular.ttf" do
        pdf.text "Rodzaj ukończonych kursów:", align: :left, size: 9
        @profile.acomplished_courses.present? && @profile.acomplished_courses.each do |course|
          pdf.move_down 2
          pdf.text "• " + I18n.t("activemodel.attributes.user_management_profile_form.profile_acomplished_courses_#{course}"), size: 8, indent_paragraphs: 10
        end
      end
    end
    pdf.grid([4,0], [4,2]).bounding_box do
      pdf.font "#{Rails.root}/app/assets/fonts/Roboto-Regular.ttf" do
        pdf.text I18n.t('activemodel.attributes.user_management_profile_form.terms_of_service_info'), size: 4, indent_paragraphs: 10
      end
    end
    pdf.grid([5,0], [5,2]).bounding_box do
      pdf.font "#{Rails.root}/app/assets/fonts/Roboto-Regular.ttf" do
        pdf.move_down 3
        pdf.text 'Załączniki:', size: 9
        pdf.move_down 3
        pdf.text "1." + 'Fotografie 3,5 cm x 4,5 cm - 2 szt.', indent_paragraphs: 10, size: 9
        pdf.move_down 3
        pdf.text "2." + 'Świadectwo ukończenia kursu.', indent_paragraphs: 10, size: 9
      end
    end

    pdf.grid([5,2], [5,2]).bounding_box do
      pdf.font "#{Rails.root}/app/assets/fonts/Roboto-Regular.ttf" do
        pdf.text '.............................................'
        pdf.move_down 3
        pdf.text 'data i czytelny podpis wnioskodawcy*', size: 9
        pdf.text '* w przypadku wysłania deklaracji pocztą e-mail podpis proszę złożyć najpóźniej w dniu odbioru legitymacji.', size: 6
      end
    end
    pdf.grid([6,0], [6,2]).bounding_box do
      pdf.font "#{Rails.root}/app/assets/fonts/Roboto-Bold.ttf" do
        pdf.stroke_horizontal_rule
        pdf.move_down 15
        pdf.text 'Decyzja zarządu', align: :center, size: 9
      end
      pdf.move_down 15
      pdf.font "#{Rails.root}/app/assets/fonts/Roboto-Regular.ttf" do
        pdf.text 'Dnia .......................................................... przyjęta/y w poczet członków zwyczajnych Klubu Wysokogórskiego Kraków.', align: :left, size: 9
      end
    end
    pdf.grid([7,0], [7,2]).bounding_box do
      pdf.font "#{Rails.root}/app/assets/fonts/Roboto-Regular.ttf" do
        pdf.text 'Numer legitymacji klubowej ......................', align: :left, size: 9
      end
    end
    pdf.grid(8,0).bounding_box do
      pdf.font "#{Rails.root}/app/assets/fonts/Roboto-Regular.ttf" do
        pdf.text '.............................', align: :center
        pdf.move_down 5
        pdf.text 'za Zarząd', align: :center, size: 9
      end
    end
    pdf.grid(8,2).bounding_box do
      pdf.font "#{Rails.root}/app/assets/fonts/Roboto-Regular.ttf" do
        pdf.text '.............................', align: :center
        pdf.move_down 5
        pdf.text 'Potwierdzam odbiór legitymacji (data, podpis)', align: :center, size: 9
      end
    end
    pdf.grid([10,0], [10,2]).bounding_box do
      pdf.font "#{Rails.root}/app/assets/fonts/Roboto-Regular.ttf" do
        pdf.text 'KRS: 00 000 22 732 REGON: ​001 263 724 NIP​: 676 10 07 059 Statut​: http://www.kw.krakow.pl/statut Bank:​ Millenium nr konta 77 1160 2202 0000 0000 3523 6899', size: 8, align: :center
      end
    end
    attachments['zgloszenie_do_kw.pdf'] = pdf.render

    I18n.with_locale(@profile.locale) do
      mail(
        to: @profile.email,
        cc: 'zgloszenia@kw.krakow.pl',
        from: 'zgloszenia@kw.krakow.pl',
        subject: I18n.t('profile_mailer.apply.subject', first_name: @profile.first_name, last_name: @profile.last_name)
      ).tap do |message|
        message.mailgun_options = {
          "mailable_id" => @profile.id,
          "mailable_type" => @profile.class.name
        }
      end
    end
  end
end
