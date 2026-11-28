# == Schema Information
#
# Table name: library_items
#
#  id               :bigint           not null, primary key
#  attachments      :string
#  autors           :string
#  countries        :text             default([]), not null, is an Array
#  description      :text
#  disciplines      :text             default([]), not null, is an Array
#  doc_type         :integer
#  edition_info     :string
#  label_printed_at :datetime
#  number           :string
#  original_title   :string
#  publishment_at   :date
#  publisher        :string
#  reading_room     :boolean          default(FALSE), not null
#  region           :string
#  slug             :string           not null
#  title            :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  area_id          :integer
#  item_id          :integer
#
module Library
  # Catalog entry for a physical book, magazine or guide. `item_id` is the library number
  # written on the book (not unique yet, see docs/LIBRARY_INVENTORY_PLAN.md step 18).
  # `title` is the Polish title; `autors` holds place and year, not authors (see `edition_info`).
  class ItemRecord < ActiveRecord::Base
    extend FriendlyId
    self.table_name = 'library_items'

    enum doc_type: [:book, :magazine, :guide]

    mount_uploaders :attachments, Library::AttachmentUploader
    serialize :attachments, JSON

    friendly_id :title, use: :slugged

    has_many :item_authors, class_name: '::Library::ItemAuthorsRecord', foreign_key: :item_id
    has_many :authors, class_name: '::Library::AuthorRecord', through: :item_authors, foreign_key: :author_id, dependent: :destroy

    has_many :library_item_reservations, class_name: '::Library::ItemReservationRecord', foreign_key: :item_id
    has_many :library_reservators, class_name: '::Db::User', through: :library_item_reservations, foreign_key: :user_id, dependent: :destroy, source: :user

    has_many :item_tags, class_name: '::Library::ItemTagsRecord', foreign_key: :item_id
    has_many :tags, class_name: '::Library::TagRecord', through: :item_tags, foreign_key: :tag_id, dependent: :destroy

    has_many :scans, -> { order(:position, :id) }, class_name: 'Library::ScanRecord',
                                                  foreign_key: :item_id, dependent: :destroy
    has_many :inventory_checks, class_name: 'Library::InventoryCheckRecord',
                                foreign_key: :item_id, dependent: :destroy

    before_validation :remove_blank_catalog_values

    validates :title, presence: { message: 'nie może być puste' }
    validate :disciplines_in_catalog
    validate :countries_in_catalog

    # Items whose library number is used more than once (302-305 and 1071 on production).
    def self.duplicated_numbers
      where(item_id: unscoped.where.not(item_id: nil).group(:item_id).having('COUNT(*) > 1').select(:item_id))
    end

    def self.next_number
      (maximum(:item_id) || 0) + 1
    end

    def on_place?
      !library_item_reservations.where(back_at: nil).any?
    end

    def authors_names=(ids)
      self.author_ids = ids
    end
    attr_reader :authors_names

    private

    # Multi-selects submit an empty string, drop it before validating.
    def remove_blank_catalog_values
      self.disciplines = Array(disciplines).compact_blank
      self.countries = Array(countries).compact_blank
    end

    def disciplines_in_catalog
      invalid = disciplines - Catalog::DISCIPLINES
      errors.add(:disciplines, "zawiera nieznane rodzaje: #{invalid.join(', ')}") if invalid.any?
    end

    def countries_in_catalog
      invalid = countries - Catalog::COUNTRIES
      errors.add(:countries, "zawiera nieznane kraje: #{invalid.join(', ')}") if invalid.any?
    end
  end
end
