# frozen_string_literal: true

class AddCatalogFieldsToLibraryItems < ActiveRecord::Migration[7.0]
  def up
    add_column :library_items, :original_title, :string
    add_column :library_items, :edition_info, :string
    add_column :library_items, :publisher, :string
    add_column :library_items, :disciplines, :text, array: true, null: false, default: []
    add_column :library_items, :countries, :text, array: true, null: false, default: []
    add_column :library_items, :region, :string
    add_column :library_items, :label_printed_at, :datetime

    # Nulls are treated as "not in the reading room"; production has none (checked 2026-11-25).
    execute 'UPDATE library_items SET reading_room = FALSE WHERE reading_room IS NULL'
    change_column_default :library_items, :reading_room, from: nil, to: false
    change_column_null :library_items, :reading_room, false
  end

  def down
    change_column_null :library_items, :reading_room, true
    change_column_default :library_items, :reading_room, from: false, to: nil

    remove_column :library_items, :label_printed_at
    remove_column :library_items, :region
    remove_column :library_items, :countries
    remove_column :library_items, :disciplines
    remove_column :library_items, :publisher
    remove_column :library_items, :edition_info
    remove_column :library_items, :original_title
  end
end
