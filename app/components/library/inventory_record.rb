# frozen_string_literal: true

# == Schema Information
#
# Table name: library_inventories
#
#  id         :bigint           not null, primary key
#  closed_at  :datetime
#  name       :string           not null
#  started_at :datetime         not null
#  state      :integer          default("in_progress"), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
module Library
  # One inventory round. Only one round can be in progress at a time (also enforced by a DB index).
  class InventoryRecord < ActiveRecord::Base
    self.table_name = 'library_inventories'

    has_many :checks, class_name: 'Library::InventoryCheckRecord', foreign_key: :inventory_id, dependent: :destroy
    has_many :checked_items, through: :checks, source: :item

    enum state: { in_progress: 0, closed: 1 }

    before_validation :set_started_at, on: :create

    validates :name, presence: { message: 'nie może być puste' }
    validate :only_one_in_progress, on: :create

    def self.current
      in_progress.first
    end

    private

    def set_started_at
      self.started_at ||= Time.current
    end

    def only_one_in_progress
      return unless in_progress?
      return unless self.class.in_progress.exists?

      errors.add(:base, 'Inwentaryzacja jest już w toku, zamknij ją przed rozpoczęciem nowej')
    end
  end
end
