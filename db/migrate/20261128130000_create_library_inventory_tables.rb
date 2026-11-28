# frozen_string_literal: true

class CreateLibraryInventoryTables < ActiveRecord::Migration[7.0]
  def change
    create_table :library_inventories do |t|
      t.string :name, null: false
      # 0 = open, 1 = closed (enum in Library::InventoryRecord)
      t.integer :state, null: false, default: 0
      t.datetime :started_at, null: false
      t.datetime :closed_at
      t.timestamps
    end

    # At most one open inventory round at a time.
    add_index :library_inventories, :state,
              unique: true, where: 'state = 0', name: 'index_library_inventories_one_open'

    create_table :library_inventory_checks do |t|
      t.references :inventory, null: false, foreign_key: { to_table: :library_inventories }
      t.references :item, null: false, foreign_key: { to_table: :library_items }
      t.datetime :checked_at, null: false
      t.text :note
      t.timestamps
    end

    add_index :library_inventory_checks, %i[inventory_id item_id],
              unique: true, name: 'index_library_inventory_checks_on_inventory_and_item'

    create_table :library_item_scans do |t|
      t.references :item, null: false, foreign_key: { to_table: :library_items }
      # 0 = cover, 1 = contents, 2 = map, 3 = other (enum in Library::ScanRecord)
      t.integer :kind, null: false, default: 3
      t.integer :position, null: false, default: 0
      t.string :image, null: false
      t.timestamps
    end

    add_index :library_item_scans, %i[item_id position], name: 'index_library_item_scans_on_item_and_position'
    # At most one cover per item.
    add_index :library_item_scans, :item_id,
              unique: true, where: 'kind = 0', name: 'index_library_item_scans_one_cover_per_item'
  end
end
