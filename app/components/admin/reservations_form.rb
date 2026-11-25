require 'active_model'

module Admin
  class ReservationsForm
    include ActiveModel::Model
    include ActiveModel::Validations
    include ActiveModel::Validations::Callbacks

    attr_accessor :kw_id, :start_date, :end_date, :remarks, :photos

    validates :kw_id, presence: { message: 'nie moze byc pusty'}
    validate :user_exists, if: -> { kw_id.present? }

    def params
      ActiveSupport::HashWithIndifferentAccess.new(
        user_id: user.id,
        start_date: start_date,
        end_date: end_date,
        remarks: remarks,
        photos: photos
      )
    end

    def user
      Db::User.find_by(kw_id: kw_id)
    end

    private

    def user_exists
      errors.add(:kw_id, 'nie ma klubowicza o takim numerze') unless user
    end
  end
end
