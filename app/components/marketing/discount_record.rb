# == Schema Information
#
# Table name: marketing_discounts
#
#  id            :bigint           not null, primary key
#  amount        :integer
#  amount_body   :string
#  amount_text   :string
#  amount_type   :integer
#  attachments   :string
#  category_type :integer
#  description   :string
#  link          :string
#  logo          :string
#  slug          :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  contractor_id :integer          not null
#  user_id       :integer
#
module Marketing
  class DiscountRecord < ActiveRecord::Base
    extend FriendlyId
    self.table_name = 'marketing_discounts'
    enum amount_type: [:percentages]
    enum category_type: [:climbing_hall]

    mount_uploaders :attachments, Management::AttachmentUploader
    serialize :attachments, JSON

    friendly_id :slug_candidates, use: :slugged

    belongs_to :contractor, class_name: 'Settlement::ContractorRecord'
    belongs_to :user, class_name: 'Db::User'
    has_many :comments, as: :commentable, class_name: 'Messaging::CommentRecord'

    validates :contractor, presence: true

    delegate :name, to: :contractor, allow_nil: true

    def slug_candidates
      [
        [:name, :id]
      ]
    end
  end
end
