require './spec/factories'

module Seeding
  class Seeder
    class << self
      def seed!
        Shop::OrderRecord.destroy_all
        Shop::ItemRecord.destroy_all
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
