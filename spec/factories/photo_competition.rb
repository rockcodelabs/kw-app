# frozen_string_literal: true

FactoryBot.define do
  factory :photo_competition_edition, class: 'PhotoCompetition::EditionRecord' do
    sequence(:code) { |n| "kasprzyk_#{2030 + n}" }
    name { 'Konkurs Fotograficzny im. Piotra Kasprzyka' }
    closed { false }
    start_voting_date { nil }
    end_voting_date { nil }
  end

  factory :photo_competition_category, class: 'PhotoCompetition::CategoryRecord' do
    # CategoryRecord#edition has no foreign_key option, so the column is set explicitly.
    transient { edition { association :photo_competition_edition } }

    edition_record_id { edition.id }
    sequence(:name) { |n| "Kategoria #{n}" }
    mandatory_fields { [] }
  end

  # The uploader stores files remotely, so the file column is set directly and validations are skipped.
  factory :photo_competition_request, class: 'PhotoCompetition::RequestRecord' do
    association :edition, factory: :photo_competition_edition
    category { association :photo_competition_category, edition: edition }
    association :user
    sequence(:title) { |n| "Zdjęcie #{n}" }
    accepted { true }
    original_filename { 'photo.jpg' }

    after(:build) { |request| request[:file] = 'photo.jpg' }
    to_create { |request| request.save!(validate: false) }
  end
end
