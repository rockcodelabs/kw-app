# frozen_string_literal: true

# == Schema Information
#
# Table name: library_item_scans
#
#  id         :bigint           not null, primary key
#  image      :string           not null
#  kind       :integer          default("other"), not null
#  position   :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  item_id    :bigint           not null
#
module Library
  # One photo of a library item (cover, contents page, map...). At most MAX_PER_ITEM per item.
  class ScanRecord < ActiveRecord::Base
    MAX_PER_ITEM = 5

    self.table_name = 'library_item_scans'

    belongs_to :item, class_name: 'Library::ItemRecord', foreign_key: :item_id

    # Prefixed (kind_cover?, kind_map?...) because a plain `map` value would clash with Relation#map.
    enum kind: { cover: 0, contents: 1, map: 2, other: 3 }, _prefix: true

    validates :image, presence: { message: 'nie może być puste' }
    validates :kind, uniqueness: { scope: :item_id, message: 'okładka jest już dodana do tej pozycji' }, if: :kind_cover?
    validate :item_scan_limit, on: :create

    private

    def item_scan_limit
      return if item.nil?
      return if item.scans.count < MAX_PER_ITEM

      errors.add(:base, "Możesz dodać maksymalnie #{MAX_PER_ITEM} zdjęć do jednej pozycji")
    end
  end
end
