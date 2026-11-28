# frozen_string_literal: true

FactoryBot.define do
  factory :library_item, class: 'Library::ItemRecord' do
    sequence(:title) { |n| "Library item #{n}" }
    # Physical library number written on the book (not the primary key).
    sequence(:item_id) { |n| 5000 + n }
    doc_type { :book }
    description { Faker::Lorem.sentence }

    trait :book do
      doc_type { :book }
    end

    trait :guide do
      doc_type { :guide }
    end

    trait :magazine do
      doc_type { :magazine }
    end
  end

  factory :library_tag, class: 'Library::TagRecord' do
    sequence(:name) { |n| "Tag #{n}" }
  end

  factory :library_author, class: 'Library::AuthorRecord' do
    sequence(:name) { |n| "Author #{n}" }
  end

  factory :library_item_reservation, class: 'Library::ItemReservationRecord' do
    association :item, factory: :library_item
    association :user, factory: :user
    received_at { Date.current }
    back_at { nil }
  end

  factory :library_scan, class: 'Library::ScanRecord' do
    association :item, factory: :library_item
    sequence(:image) { |n| "scan-#{n}.jpg" }
    kind { :other }

    trait :cover do
      kind { :cover }
    end
  end

  factory :library_inventory, class: 'Library::InventoryRecord' do
    sequence(:name) { |n| "Inwentaryzacja #{n}" }
    state { :in_progress }

    trait :closed do
      state { :closed }
      closed_at { Time.current }
    end
  end

  factory :library_inventory_check, class: 'Library::InventoryCheckRecord' do
    association :inventory, factory: :library_inventory
    association :item, factory: :library_item
  end
end
