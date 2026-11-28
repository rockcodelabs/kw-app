# frozen_string_literal: true

# == Schema Information
#
# Table name: library_inventory_checks
#
#  id           :bigint           not null, primary key
#  checked_at   :datetime         not null
#  note         :text
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  inventory_id :bigint           not null
#  item_id      :bigint           not null
#
module Library
  # "This item was seen on the shelf" in one inventory round.
  class InventoryCheckRecord < ActiveRecord::Base
    self.table_name = 'library_inventory_checks'

    belongs_to :inventory, class_name: 'Library::InventoryRecord', foreign_key: :inventory_id
    belongs_to :item, class_name: 'Library::ItemRecord', foreign_key: :item_id

    before_validation :set_checked_at

    validates :item_id, uniqueness: { scope: :inventory_id, message: 'została już sprawdzona w tej inwentaryzacji' }

    private

    def set_checked_at
      self.checked_at ||= Time.current
    end
  end
end
