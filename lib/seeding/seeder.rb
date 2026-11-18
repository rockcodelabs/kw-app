require './spec/factories'

module Seeding
  class Seeder
    class << self
      def seed!
        Db::Membership::Fee.destroy_all
        Factories::Membership::Fee.mass_create!(range: (1..20), state: 'prepaid', cash: false)
        Factories::Membership::Fee.mass_create!(range: (21..40), state: 'unpaid', cash: true)
        Factories::Membership::Fee.mass_create!(range: (41..50), state: 'unpaid', cash: false)
        Factories::Membership::Fee.mass_create!(range: (51..80), state: 'prepaid', cash: true)
        Factories::Membership::Fee.mass_create!(range: (81..100), years: [2016, 2017], state: 'prepaid', cash: false)
        Db::Profile.destroy_all
        (1..80).step(1) do |i|
          profile = Factories::Profile.create!(
            first_name: Faker::Name.first_name,
            last_name: Faker::Name.last_name,
            email: Faker::Internet.unique.email,
            phone: Faker::PhoneNumber.cell_phone,
            position: 2.times.map { Db::Profile::POSITION.sample }.uniq,
            acomplished_courses: 2.times.map { Db::Profile::ACOMPLISHED_COURSES.sample }.uniq,
            sections: 2.times.map { Db::Profile::SECTIONS.sample }.uniq,
            recommended_by: 3.times.map { Db::Profile::RECOMMENDED_BY.sample }.uniq,
            cost: [100, 50, 150].sample,
            added: [true, false].sample,
            accepted: false,
            main_discussion_group: [true, false].sample,
            application_date: Faker::Date.between(from: 2.years.ago, to: Date.today),
            birth_date: Faker::Date.birthday(min_age: 18, max_age: 65),
            kw_id: nil,
            city: Faker::Address.city,
            birth_place: Faker::Address.city,
            pesel: Faker::Code.ean,
            postal_code: Faker::Address.postcode,
            main_address: Faker::Address.street_address,
            optional_address: Faker::Address.secondary_address
          )
          profile.create_payment(dotpay_id: SecureRandom.hex(13))
        end
        (81..100).step(1) do |i|
          profile = Factories::Profile.create!(
            first_name: Faker::Name.first_name,
            last_name: Faker::Name.last_name,
            email: Faker::Internet.unique.email,
            phone: Faker::PhoneNumber.cell_phone,
            position: 2.times.map { Db::Profile::POSITION.sample }.uniq,
            acomplished_courses: 2.times.map { Db::Profile::ACOMPLISHED_COURSES.sample }.uniq,
            sections: 2.times.map { Db::Profile::SECTIONS.sample }.uniq,
            recommended_by: 3.times.map { Db::Profile::RECOMMENDED_BY.sample }.uniq,
            cost: [100, 50, 150].sample,
            added: [true, false].sample,
            accepted: true,
            gender: [:male, :female].sample,
            main_discussion_group: [true, false].sample,
            application_date: Faker::Date.between(from: 2.years.ago, to: Date.today),
            birth_date: Faker::Date.birthday(min_age: 18, max_age: 65),
            kw_id: i,
            city: Faker::Address.city,
            birth_place: Faker::Address.city,
            pesel: Faker::Code.ean,
            postal_code: Faker::Address.postcode,
            main_address: Faker::Address.street_address,
            optional_address: Faker::Address.secondary_address
          )
          profile.create_payment(dotpay_id: SecureRandom.hex(13), cash: false, state: 'prepaid')
        end
        Db::User.destroy_all
        Db::Profile.where(kw_id: (81..100)).each do |profile|
          user = Db::User.new(kw_id: profile.kw_id, first_name: profile.first_name, gender: [:male, :female].sample, last_name: profile.last_name, email: profile.email, phone: profile.phone)
          user.password = "test#{profile.id}"
          user.save
          fee = user.membership_fees.create year: Date.today.year, cost: 100, kw_id: user.kw_id, creator_id: user.id
          fee.create_payment cash: true, state: 'prepaid', cash_user_id: Db::User.first.id
        end
        Factories::Profile.create!(
          first_name: 'Dariusz',
          last_name: 'Finster',
          email: 'dariusz.finster@gmail.com',
          phone: Faker::PhoneNumber.cell_phone,
          position: 2.times.map { Db::Profile::POSITION.sample }.uniq,
          acomplished_courses: 2.times.map { Db::Profile::ACOMPLISHED_COURSES.sample }.uniq,
          sections: 2.times.map { Db::Profile::SECTIONS.sample }.uniq,
          recommended_by: 3.times.map { Db::Profile::RECOMMENDED_BY.sample }.uniq,
          cost: [100, 50, 150].sample,
          added: [true, false].sample,
          accepted: true,
          main_discussion_group: [true, false].sample,
          application_date: Faker::Date.between(from: 2.years.ago, to: Date.today),
          birth_date: Faker::Date.birthday(min_age: 18, max_age: 65),
          kw_id: 2345,
          city: Faker::Address.city,
          birth_place: Faker::Address.city,
          pesel: Faker::Code.ean,
          postal_code: Faker::Address.postcode,
          main_address: Faker::Address.street_address,
          optional_address: Faker::Address.secondary_address
        )
        Factories::Profile.create!(
          first_name: 'Mikolaj',
          last_name: 'Rydzewski',
          email: 'mikolaj.rydzewski@gmail.com',
          phone: Faker::PhoneNumber.cell_phone,
          position: 2.times.map { Db::Profile::POSITION.sample }.uniq,
          acomplished_courses: 2.times.map { Db::Profile::ACOMPLISHED_COURSES.sample }.uniq,
          sections: 2.times.map { Db::Profile::SECTIONS.sample }.uniq,
          recommended_by: 3.times.map { Db::Profile::RECOMMENDED_BY.sample }.uniq,
          cost: [100, 50, 150].sample,
          added: [true, false].sample,
          accepted: true,
          main_discussion_group: [true, false].sample,
          application_date: Faker::Date.between(from: 2.years.ago, to: Date.today),
          birth_date: Faker::Date.birthday(min_age: 18, max_age: 65),
          kw_id: 2794,
          city: Faker::Address.city,
          birth_place: Faker::Address.city,
          pesel: Faker::Code.ean,
          postal_code: Faker::Address.postcode,
          main_address: Faker::Address.street_address,
          optional_address: Faker::Address.secondary_address
        )
         Factories::Profile.create!(
          first_name: 'Piotr',
          last_name: 'Podolski',
          email: 'piotr.podolski@gmail.com',
          phone: Faker::PhoneNumber.cell_phone,
          position: 2.times.map { Db::Profile::POSITION.sample }.uniq,
          acomplished_courses: 2.times.map { Db::Profile::ACOMPLISHED_COURSES.sample }.uniq,
          sections: 2.times.map { Db::Profile::SECTIONS.sample }.uniq,
          recommended_by: 3.times.map { Db::Profile::RECOMMENDED_BY.sample }.uniq,
          cost: [100, 50, 150].sample,
          added: [true, false].sample,
          accepted: true,
          main_discussion_group: [true, false].sample,
          application_date: Faker::Date.between(from: 2.years.ago, to: Date.today),
          birth_date: Faker::Date.birthday(min_age: 18, max_age: 65),
          kw_id: 3123,
          city: Faker::Address.city,
          birth_place: Faker::Address.city,
          pesel: Faker::Code.ean,
          postal_code: Faker::Address.postcode,
          main_address: Faker::Address.street_address,
          optional_address: Faker::Address.secondary_address
        )
        user1 = Db::User.new(
          first_name: 'Małgorzata',
          last_name: 'Kozak',
          email: 'm.kozak1980@gmail.com',
          kw_id: 1720,
          phone: Faker::PhoneNumber.cell_phone,
          admin: true
        )
        user1.password = "test"
        user1.save
        user2 = Db::User.new(
          first_name: 'Bartłomiej',
          last_name: 'Klimas',
          email: 'klimas.bartlomiej@gmail.com',
          kw_id: 1720,
          phone: Faker::PhoneNumber.cell_phone,
          admin: true
        )
        user2.password = "test"
        user2.save
        user3 = Db::User.new(
          first_name: 'Dariusz',
          last_name: 'Finster',
          email: 'dariusz.finster@gmail.com',
          kw_id: 2345,
          phone: Faker::PhoneNumber.cell_phone,
          roles: ['admin', 'office']
        )
        user3.password = "test"
        user3.save
        fee = user3.membership_fees.create year: Date.today.year, cost: 100, kw_id: user3.kw_id, creator_id: user3.id
        fee.create_payment cash: true, state: 'prepaid', cash_user_id: Db::User.first.id
        user4 = Db::User.new(
          first_name: 'Piotr',
          last_name: 'Podolski',
          email: 'piotr.podolski@gmail.com',
          kw_id: 3123,
          phone: Faker::PhoneNumber.cell_phone,
          roles: ['admin', 'office']
        )
        user4.password = "test"
        user4.save
        fee = user4.membership_fees.create year: Date.today.year, cost: 100, kw_id: user4.kw_id, creator_id: user4.id
        fee.create_payment cash: true, state: 'prepaid', cash_user_id: Db::User.first.id
        user5 = Db::User.new(
          first_name: 'Mikolaj',
          last_name: 'Rydzewski',
          email: 'mikolaj.rydzewski@gmail.com',
          kw_id: 2794,
          phone: Faker::PhoneNumber.cell_phone,
          roles: ['admin', 'office']
        )
        user5.password = "test"
        user5.save
        fee = user5.membership_fees.create year: Date.today.year, cost: 100, kw_id: user5.kw_id, creator_id: user5.id
        fee.create_payment cash: true, state: 'prepaid', cash_user_id: Db::User.first.id
        Db::Item.destroy_all
        (1..10).step(1) do |n|
          Factories::Item.create!(id: n, display_name: Faker::Commerce.product_name, owner: ['snw', 'kw'].sample)
        end
        Db::Activities::MountainRoute.destroy_all
        200.times do
          Db::Activities::MountainRoute.create(
            user: Db::User.all.sample,
            name: Faker::Mountain.name,
            description: Faker::Lorem.paragraph,
            peak: Faker::Mountain.name,
            area: Faker::Mountain.range,
            mountains: Faker::Mountain.range,
            colleagues: Db::User.all.sample(2),
            difficulty: ['+IV', '6', 'M6', 'V'].sample,
            partners: [Faker::Artist.name, Faker::Artist.name].to_sentence,
            rating: [1, 2, 3].sample,
            climbing_date: Faker::Date.backward(days: 23),
            route_type: [0, 1].sample,
            length: Faker::Number.within(range: 100..2500),
            hidden: Faker::Boolean.boolean(true_ratio: 0.2),
            training: Faker::Boolean.boolean(true_ratio: 0.3)
          )
        end
        
        # Add test images to last 3 mountain routes (only in development/staging)
        if Rails.env.development? || Rails.env.staging?
          require 'open-uri'
          require 'tempfile'
          
          puts "Adding test images to last 3 mountain routes..."
          
          # Sample mountain/climbing images from Unsplash
          image_urls = [
            'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800',  # Mountain landscape
            'https://images.unsplash.com/photo-1519904981063-b0cf448d479e?w=800',  # Rock climbing
            'https://images.unsplash.com/photo-1551632811-561732d1e306?w=800'   # Mountain peak
          ]
          
          Db::Activities::MountainRoute.last(3).each_with_index do |route, index|
            begin
              image_url = image_urls[index % image_urls.length]
              
              # Create Storage::UploadRecord with remote URL
              # CarrierWave will download and process it automatically
              upload = Storage::UploadRecord.new(
                uploadable: route,
                user: route.user,
                content_type: 'image/jpeg'
              )
              upload.remote_file_url = image_url
              upload.save!
              
              puts "  ✓ Added image to route: #{route.name}"
              
              # Small delay to avoid rate limiting
              sleep 2
            rescue => e
              puts "  ✗ Failed to add image to route #{route.name}: #{e.message}"
            end
          end
          
          puts "Finished adding test images!"
        end
        
        # Add 3 sale announcements with 3 images each (only in development/staging)
        if Rails.env.development? || Rails.env.staging?
          require 'open-uri'
          require 'tempfile'
          
          puts "Creating sale announcements with images..."
          
          Olx::SaleAnnouncementRecord.destroy_all
          
          # Sample product images from Unsplash
          gear_images = [
            'https://images.unsplash.com/photo-1551698618-1dfe5d97d256?w=800',  # Climbing gear
            'https://images.unsplash.com/photo-1504280390367-361c6d9f38f4?w=800',  # Camping equipment
            'https://images.unsplash.com/photo-1486218119243-13883505764c?w=800',  # Hiking boots
            'https://images.unsplash.com/photo-1622260614153-03223fb72052?w=800',  # Backpack
            'https://images.unsplash.com/photo-1522163182402-834f871fd851?w=800',  # Climbing rope
            'https://images.unsplash.com/photo-1624623278313-a930126a11c3?w=800',  # Carabiners
            'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800',  # Tent
            'https://images.unsplash.com/photo-1520095972714-909e91b038e5?w=800',  # Sleeping bag
            'https://images.unsplash.com/photo-1578608712688-36b5be8823dc?w=800'   # Mountain bike
          ]
          
          announcements = [
            { name: 'Zestaw asekuracyjny (7 ekspresów + lina 70m)', description: 'Kompletny zestaw do wspinaczki skalnej. Ekspres w dobrym stanie, lina używana ale sprawna. Idealny na początek przygody ze wspinaczką.', price: 450.0 },
            { name: 'Buty wspinaczkowe La Sportiva rozmiar 42', description: 'Bardzo wygodne buty wspinaczkowe, lekko używane. Świetnie sprawdzają się na dłuższych drogach. Sprzedaję bo za małe.', price: 280.0 },
            { name: 'Plecak górski 65L + materac', description: 'Solidny plecak turystyczny z systemem wentylacji pleców. W zestawie samonośny materac. Kilka wypraw w Tatrach, stan bardzo dobry.', price: 320.0 }
          ]
          
          announcements.each_with_index do |announcement_data, index|
            user = Db::User.all.sample
            
            announcement = Olx::SaleAnnouncementRecord.create!(
              name: announcement_data[:name],
              description: announcement_data[:description],
              price: announcement_data[:price],
              user: user,
              archived: false
            )
            
            # Add 3 images to each announcement
            3.times do |img_index|
              begin
                image_url = gear_images[(index * 3 + img_index) % gear_images.length]
                
                # Create Storage::UploadRecord with remote URL
                # CarrierWave will download and process it automatically
                upload = Storage::UploadRecord.new(
                  uploadable: announcement,
                  user: user,
                  content_type: 'image/jpeg'
                )
                upload.remote_file_url = image_url
                upload.save!
                
                puts "  ✓ Added image #{img_index + 1}/3 to: #{announcement.name}"
                
                # Small delay to avoid rate limiting
                sleep 2
              rescue => e
                puts "  ✗ Failed to add image to announcement #{announcement.name}: #{e.message}"
              end
            end
          end
          
          puts "Finished creating #{announcements.count} sale announcements!"
        end
        

        trad_route_names = [
          'Filar Północny', 'Droga Klasyczna', 'Rysa Zachodnia', 'Komin Południkowy',
          'Ściana Wschodnia', 'Grań Orła', 'Filar Kozicy', 'Kominek Sokoli',
          'Zachodnia Galeria', 'Droga przez Płytę', 'Rysa Centralna', 'Żebro Główne',
          'Komin Taternika', 'Filaret Turni', 'Wielka Rysa', 'Direttissima',
          'Filar Południa', 'Droga Zimowa', 'Komin Wiatrów', 'Ściana Ciszy',
          'Żebro Wschodnie', 'Galeria nad Przepaścią', 'Wąski Komin', 'Turnia Ptaków'
        ]
        trad_areas = ['Tatry Wysokie', 'Tatry Zachodnie', 'Jura Krakowsko-Częstochowska', 'Góry Sokole', 'Rudawy Janowickie']
        kurtyka_grades = ['III', 'IV', 'IV+', 'V', 'V+', 'VI', 'VI+', 'VI.1', 'VI.1+', 'VI.2']
        users = Db::User.all.to_a

        users.each do |user|
          rand(2..6).times do
            Db::Activities::MountainRoute.create(
              user: user,
              name: trad_route_names.sample,
              description: Faker::Lorem.paragraph,
              peak: Faker::Mountain.name,
              area: trad_areas.sample,
              mountains: trad_areas.sample,
              colleagues: users.sample(rand(0..2)),
              difficulty: kurtyka_grades.sample,
              kurtyka_difficulty: kurtyka_grades.sample,
              partners: [Faker::Name.name, Faker::Name.name].sample(rand(0..2)).to_sentence,
              rating: [1, 2, 3].sample,
              climbing_date: Faker::Date.between(from: Date.new(2026, 1, 1), to: [Date.today, Date.new(2026, 12, 31)].min),
              route_type: :trad_climbing,
              length: Faker::Number.within(range: 10..400),
              hidden: false,
              training: false
            )
          end
        end
        Management::News::InformationRecord.destroy_all
        45.times do
          Management::News::InformationRecord.create(
            name: Faker::Lorem.sentence,
            description: Faker::Lorem.paragraph,
            url: [nil, Faker::Internet.url].sample,
            news_type: [0, 1, 2].sample,
            group_type: [0, 1, 2, 3].sample,
            starred: Faker::Boolean.boolean(true_ratio: 0.2),
            web: Faker::Boolean.boolean(true_ratio: 0.2)
          )
        end
        Training::Supplementary::CourseRecord.destroy_all
        100.times do
          start_time = Faker::Time.between_dates(from: Date.today - 10, to: Date.today + 50, period: :afternoon)
          Training::Supplementary::CourseRecord.create(
            name: Faker::Lorem.sentence,
            place: Faker::Space.constellation,
            start_date: start_time,
            end_date: [start_time, start_time + 3.days].sample,
            organizator_id: Db::User.all.map(&:id).sample,
            price_kw: 10,
            application_date: start_time - 5.days,
            accepted: true,
            remarks: Faker::Lorem.paragraph,
            category: [0, 1, 2].sample,
            price: true,
            limit: 10,
            one_day: false,
            active: true,
            open: false,
            last_fee_paid: false,
            cash: false,
            kind: [0, 1, 2, 3, 4, 5].sample,
            state: [0, 1, 2, 3].sample,
            payment_type: [0, 1].sample,
            baner_type: [0, 1].sample,
            expired_hours: 24,
            end_application_date: start_time - 1.day
          )
        end
        Management::ProjectRecord.destroy_all
        50.times do
          Management::ProjectRecord.create(
            name: Faker::Lorem.sentence,
            description: Faker::Lorem.paragraph,
            coordinator_id: Db::User.all.map(&:id).sample,
            needed_knowledge: Faker::Lorem.paragraph,
            benefits: Faker::Lorem.paragraph,
            estimated_time: Faker::Lorem.paragraph,
            know_how: Faker::Lorem.paragraph,
            users: Db::User.all.sample(2),
            state: [:draft, :unassigned, :in_progress, :suspended, :archived].sample,
            group_type: [:kw, :snw, :sww].sample
          )
        end
      end
    end
  end
end
