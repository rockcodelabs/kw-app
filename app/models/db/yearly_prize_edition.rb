# == Schema Information
#
# Table name: yearly_prize_editions
#
#  id                :bigint           not null, primary key
#  closed            :boolean          default(FALSE), not null
#  description       :text
#  end_voting_date   :datetime
#  name              :string           not null
#  start_voting_date :datetime
#  votable           :boolean          default(FALSE), not null
#  year              :integer          not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
class Db::YearlyPrizeEdition < ApplicationRecord
  self.table_name = 'yearly_prize_editions'

  has_many :yearly_prize_categories, class_name: 'Db::YearlyPrizeCategory', foreign_key: :yearly_prize_edition_id, dependent: :destroy
  has_many :yearly_prize_requests, class_name: 'Db::YearlyPrizeRequest', foreign_key: :yearly_prize_edition_id, dependent: :destroy

  validates :name, presence: true
  validates :year, presence: true, uniqueness: true

  def self.for_year(year)
    find_by(year: year)
  end

  def voting_started?(now = Time.current)
    start_voting_date.present? && now >= start_voting_date
  end

  def finished?(now = Time.current)
    closed || (end_voting_date.present? && end_voting_date < now)
  end

  # Klubowa Ósemka is not a category: it goes to the nomination with the most votes across the three categories.
  def self.create_with_categories(year)
    edition = Db::YearlyPrizeEdition.create(name: "Klubowa Ósemka", year: year)
    edition.yearly_prize_categories.create(name: 'Ósemka STJ')
    edition.yearly_prize_categories.create(name: 'Ósemka SNW')
    edition.yearly_prize_categories.create(name: 'Ósemka SWW')
  end
end
