# == Schema Information
#
# Table name: events_sign_ups
#
#  id                            :integer          not null, primary key
#  expired_at                    :datetime
#  friday_night                  :boolean          default(FALSE), not null
#  license_number                :integer
#  participant_birth_year_1      :string
#  participant_birth_year_2      :string
#  participant_city_1            :string
#  participant_city_2            :string
#  participant_country_1         :integer
#  participant_country_2         :integer
#  participant_email_1           :string
#  participant_email_2           :string
#  participant_first_name_1      :string
#  participant_gender_1          :string
#  participant_gender_2          :string
#  participant_kw_id_1           :integer
#  participant_kw_id_2           :integer
#  participant_license_id_1      :integer
#  participant_license_id_2      :integer
#  participant_name_1            :string
#  participant_name_2            :string
#  participant_phone_1           :string
#  participant_phone_2           :string
#  participant_team_1            :string
#  participant_team_2            :string
#  remarks                       :text
#  rescuer                       :boolean          default(FALSE), not null
#  saturday_night                :boolean          default(FALSE), not null
#  sent_at                       :datetime
#  single                        :boolean          default(FALSE), not null
#  start_number                  :integer
#  team_name                     :string
#  tshirt_size_1                 :string
#  tshirt_size_2                 :string
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  competition_package_type_1_id :integer          not null
#  competition_package_type_2_id :integer
#  competition_record_id         :integer          not null
#  teammate_id                   :integer
#
module Events
  module Db
    class SignUpRecord < ActiveRecord::Base
      self.table_name = 'events_sign_ups'
      has_paper_trail

      enum participant_country_1: [:pl, :sk, :cz, :de, :ua, :it, :fr, :at, :ch, :esp, :ro, :gr, :other], _prefix: :country_1
      enum participant_country_2: [:pl, :sk, :cz, :de, :ua, :it, :fr, :at, :ch, :esp, :ro, :gr, :other], _prefix: :country_2

      has_one :payment,
        as: :payable,
        dependent: :destroy,
        class_name: 'Db::Payment'
      belongs_to :competition_record,
        class_name: 'Events::Db::CompetitionRecord'
      validates_acceptance_of :terms_of_service
      validates_acceptance_of :medical_rules
      has_many :emails, as: :mailable, class_name: 'EmailCenter::EmailRecord', dependent: :destroy

      def self.human_enum(enum, options = {})
        [["Polska", 'pl'], ["Slovakia", "sk"], ["Czech", 'cz'], ["Germany", 'de'], ["Austria", "at"], ["Greece", "gr"], ["Italy", "it"], ["France", "fr"], ["Spain", "esp"], ["Romania", "ro"], ["Ukraine", 'ua'], ["Other", "other"]]
      end

      def sport_category_1
        return nil unless participant_birth_year_1.present?
        return nil unless competition_record.event_date.present?
        event_year = competition_record.event_date.year

        case
        when participant_birth_year_1.to_i.between?(event_year - 18, event_year - 17)
          if participant_gender_1 == "1"
            "Junior Młodszy (U18)"
          else
            "Juniorka Młodsza (U18)"
          end
        when participant_birth_year_1.to_i.between?(event_year - 20, event_year - 19)
          if participant_gender_1 == "1"
            "Junior (U20)"
          else
            "Juniorka (U20)"
          end
        when participant_birth_year_1.to_i.between?(event_year - 49, event_year - 21)
          if participant_gender_1 == "1"
            "Senior"
          else
            "Seniorka"
          end
        when participant_birth_year_1.to_i.between?(1900, event_year - 50)
          if participant_gender_1 == "1"
            "Nestor"
          else
            "Nestorka"
          end
        else
          "ERROR"
        end
      end

      def team_category
        return "Męska" if participant_gender_1 == "1" && participant_gender_2 == "1"
        return "Kobieca" if participant_gender_1 == "2" && participant_gender_2 == "2"
        return "Mix"
      end

      def gender_1
        if participant_gender_1 == "1"
          'Mężczyzna'
        else
          'Kobieta'
        end
      end

      def gender_2
        if participant_gender_2 == "1"
          'Mężczyzna'
        else
          'Kobieta'
        end
      end

      def package_type_1_membership?
        return false unless Events::Db::CompetitionPackageTypeRecord.exists?(competition_package_type_1_id)
        Events::Db::CompetitionPackageTypeRecord.find(competition_package_type_1_id).membership
      end

      def package_type_2_membership?
        return false unless Events::Db::CompetitionPackageTypeRecord.exists?(competition_package_type_2_id)
        Events::Db::CompetitionPackageTypeRecord.find(competition_package_type_2_id).membership
      end

      def package_type_1
        Events::Db::CompetitionPackageTypeRecord.find_by(id: competition_package_type_1_id)
      end

      def package_type_2
        Events::Db::CompetitionPackageTypeRecord.find_by(id: competition_package_type_2_id)
      end

      def package_types
        [package_type_1, package_type_2].compact
      end

      def cost
        package_types.map(&:cost).reduce(:+)
      end

      def payment_type
        :trainings
      end

      def participant_clubs
        [participant_team_1, participant_team_2].map(&:to_s).reject(&:empty?).compact.join(' / ')
      end

      def participant_names
        [participant_name_1, participant_name_2].map(&:to_s).reject(&:empty?).compact.join(' / ')
      end

      def participant_cities
        [participant_city_1, participant_city_2].map(&:to_s).reject(&:empty?).compact.join(' / ')
      end

      def participant_name
        participant_first_name_1.present? ? "#{participant_first_name_1} #{participant_name_1}" : participant_name_1
      end

      def description
        if single
          "Wpisowe nr #{id} na zawody #{competition_record.name} od #{participant_name}"
        else
          "Wpisowe nr #{id} na zawody #{competition_record.name} od #{participant_name_1} oraz #{participant_name_2}"
        end
      end
    end
  end
end
