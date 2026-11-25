# frozen_string_literal: true

FactoryBot.define do
  factory :yearly_prize_edition, class: 'Db::YearlyPrizeEdition' do
    name { 'Klubowa Ósemka' }
    sequence(:year) { |n| 2030 + n }
    closed { false }
    start_voting_date { nil }
    end_voting_date { nil }
  end

  factory :yearly_prize_category, class: 'Db::YearlyPrizeCategory' do
    association :yearly_prize_edition
    sequence(:name) { |n| "Ósemka #{n}" }
  end

  factory :yearly_prize_request, class: 'Db::YearlyPrizeRequest' do
    association :yearly_prize_edition
    yearly_prize_category { association :yearly_prize_category, yearly_prize_edition: yearly_prize_edition }
    association :author, factory: :user
    author_description { 'Opis autora' }

    transient do
      nominees { [] }
    end

    after(:create) do |request, evaluator|
      request.users << evaluator.nominees if evaluator.nominees.any?
    end
  end

  factory :like, class: 'Like' do
    association :user
    association :likeable, factory: :yearly_prize_request
  end
end
