# == Schema Information
#
# Table name: photo_requests
#
#  id                 :integer          not null, primary key
#  accepted           :boolean          default(FALSE), not null
#  area               :string
#  description        :string
#  file               :string
#  likes_count        :integer          default(0), not null
#  original_filename  :string
#  title              :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  category_record_id :integer          not null
#  edition_record_id  :integer          not null
#  user_id            :integer          not null
#
module PhotoCompetition
  class RequestRecord < ActiveRecord::Base
    self.table_name = 'photo_requests'

    MAX_PHOTOS_PER_CATEGORY = 5

    has_paper_trail only: [:accepted]

    mount_uploader :file, ::PhotoCompetition::FileUploader
    belongs_to :edition, class_name: '::PhotoCompetition::EditionRecord', foreign_key: :edition_record_id
    belongs_to :user, class_name: 'Db::User'
    belongs_to :category, class_name: '::PhotoCompetition::CategoryRecord', foreign_key: :category_record_id

    has_many :likes, as: :likeable, class_name: 'Like', dependent: :destroy

    validates :edition, :user, :category, :file, presence: true
    validates :title, presence: true, if: :title_needed?
    validates :area, presence: true, if: :area_needed?
    validates :description, presence: true, if: :description_needed?
    validate :category_photo_limit_not_exceeded, on: :create

    def description_needed?
      category && category.mandatory_fields.include?('description')
    end

    def title_needed?
      category && category.mandatory_fields.include?('title')
    end

    def area_needed?
      category && category.mandatory_fields.include?('area')
    end

    private

    def category_photo_limit_not_exceeded
      return unless user_id && edition_record_id && category_record_id

      submitted = self.class.where(user_id: user_id, edition_record_id: edition_record_id, category_record_id: category_record_id).count
      return if submitted < MAX_PHOTOS_PER_CATEGORY

      errors.add(:base, "Możesz zgłosić maksymalnie #{MAX_PHOTOS_PER_CATEGORY} zdjęć w jednej kategorii")
    end
  end
end
