# == Schema Information
#
# Table name: profiles
#
#  id                    :integer          not null, primary key
#  accepted              :boolean          default(FALSE)
#  accepted_at           :datetime
#  acomplished_courses   :text             default([]), is an Array
#  added                 :boolean          default(FALSE)
#  application_date      :date
#  birth_date            :date
#  birth_place           :string
#  city                  :string
#  cost                  :integer
#  course_cert           :string
#  date_of_death         :date
#  email                 :string
#  first_name            :string
#  gender                :integer
#  last_name             :string
#  locale                :string           default("pl"), not null
#  main_address          :string
#  main_discussion_group :boolean          default(FALSE)
#  optional_address      :string
#  pesel                 :string
#  phone                 :string
#  photo                 :string
#  plastic               :boolean          default(FALSE), not null
#  position              :text             default([]), is an Array
#  postal_code           :string
#  profession            :string
#  recommended_by        :text             default([]), is an Array
#  remarks               :text
#  sections              :text             default([]), is an Array
#  sent_at               :datetime
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  acceptor_id           :integer
#  kw_id                 :integer
#
# Indexes
#
#  index_profiles_on_kw_id  (kw_id) UNIQUE
#
module Db
  class Profile < ActiveRecord::Base
    RECOMMENDED_BY = %w(google facebook friends festival poster course)
    POSITION = %w(candidate regular honorable_kw honorable_pza management senior instructor canceled stj released retired)
    SECTIONS = %w(snw sww stj gtw kts)
    ACOMPLISHED_COURSES = %w(basic_kw basic basic_without_second second second_winter cave cave_kw ski list blank instructors other_club)
    enum gender: [:male, :female]

    after_save :sync_user_gender, if: :sync_user_gender?

    def self.model_name
      ActiveModel::Name.new("Db::Profile", nil, "Profile")
    end

    mount_uploader :photo, ::UserManagement::PhotoUploader
    mount_uploader :course_cert, AttachmentUploader

    has_one :payment, as: :payable, dependent: :destroy
    has_one :list, class_name: 'UserManagement::ProfileListRecord'
    has_many :membership_fees, foreign_key: :kw_id, primary_key: :kw_id, class_name: 'Db::Membership::Fee'
    has_many :comments, as: :commentable, class_name: 'Messaging::CommentRecord'
    belongs_to :user, foreign_key: :kw_id, primary_key: :kw_id
    has_many :emails, as: :mailable, class_name: 'EmailCenter::EmailRecord', dependent: :destroy

    validates :email, uniqueness: true, allow_blank: true, allow_nil: true
    validates :kw_id, uniqueness: true, allow_blank: true, allow_nil: true
    validate :kw_id_accepted

    ransacker :recommended_by do
      Arel.sql("array_to_string(recommended_by, ',')")
    end
    ransacker :position do
      Arel.sql("array_to_string(position, ',')")
    end
    ransacker :sections do
      Arel.sql("array_to_string(sections, ',')")
    end
    ransacker :acomplished_courses do
      Arel.sql("array_to_string(acomplished_courses, ',')")
    end
    ransacker :full_name do |parent|
      Arel::Nodes::NamedFunction.new('CONCAT_WS', [
        Arel::Nodes.build_quoted(' '), parent.table[:first_name], parent.table[:last_name]
      ])
    end

    def youth?
      return false unless birth_date

      Date.today.year - birth_date.year <= 26
    end

    def retired?
      position.include?("retired")
    end

    def kw_id_accepted
      if kw_id.present? && !accepted
        errors.add(:kw_id, "nie może być podany jeżeli nie zaakceptowano profilu")
      end
    end

    def display_name
      "#{first_name} #{last_name}"
    end

    def payment_type
      :fees
    end

    def description
      "Wpisowe oraz składka członkowska za rok #{::Membership::Activement.new.payment_year} od #{first_name} #{last_name}."
    end

    private

    def sync_user_gender?
      saved_change_to_gender? || saved_change_to_kw_id?
    end

    def sync_user_gender
      return if kw_id.blank? || gender.blank? || user.blank?

      user.update_column(:gender, Db::User.genders.fetch(gender))
    end
  end
end
