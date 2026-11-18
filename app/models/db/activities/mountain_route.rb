# == Schema Information
#
# Table name: mountain_routes
#
#  id                   :integer          not null, primary key
#  area                 :string
#  attachments          :string
#  boar_length          :integer          default(0)
#  climb_style          :integer
#  climbing_date        :date
#  description          :text
#  difficulty           :string
#  distance             :float
#  gps_tracks           :string
#  hearts_count         :integer          default(0)
#  hidden               :boolean          default(FALSE), not null
#  kurtyka_difficulty   :integer
#  length               :integer
#  map_summary_polyline :string
#  mountains            :string
#  name                 :string
#  partners             :string
#  peak                 :string
#  photograph           :string
#  rating               :integer
#  route_type           :integer          default("ski")
#  slug                 :string
#  time                 :string
#  training             :boolean          default(FALSE), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  strava_id            :string
#  user_id              :integer
#
# Indexes
#
#  index_mountain_routes_on_climbing_date  (climbing_date)
#  index_mountain_routes_on_slug           (slug) UNIQUE
#  index_mountain_routes_on_user_id        (user_id)
#
module Db
  module Activities
    class MountainRoute < ActiveRecord::Base
      extend FriendlyId

      before_save :save_boar_length, if: :ski?

      #searchkick word_start: %i[name] unless Rails.env.production?

      enum climb_style: {
        'RP': 0, 'Flash': 1, 'OS': 2, 'Greenpoint': 3
      }

      enum kurtyka_difficulty: {
        'III': 0, 'IV': 1, 'IV+': 2, 'V': 3, 'V+': 4, 'VI': 5, 'VI+': 6, 'VI.1': 7,
        'VI.1+': 8, 'VI.2': 9, 'VI.2+': 10, 'VI.3': 11, 'VI.3+': 12, 'VI.4': 13, 'VI.4+': 14,
        'VI.5': 15, 'VI.5+': 16
      }

      enum route_type: [:ski, :regular_climbing, :sport_climbing, :trad_climbing]

      friendly_id :slug_candidates, use: :slugged

      mount_uploaders :attachments, AttachmentUploader
      mount_uploaders :gps_tracks, Training::Activities::GpsTrackUploader
      serialize :attachments, JSON
      serialize :gps_tracks, JSON
      def self.model_name
        ActiveModel::Name.new(self, nil, "Activities::MountainRoute")
      end
      scope :climbing, -> { where(route_type: [:regular_climbing, :winter_climbing, :sport_climbing, :trad_climbing], training: false) }
      scope :skis, -> { where(route_type: :ski, training: false) }
      scope :boars, -> { where(training: [false, true]) }

      belongs_to :user
      has_many :hearts
      has_many :users, through: :hearts, dependent: :destroy
      has_many :route_colleagues, class_name: 'Db::Activities::RouteColleagues'
      has_many :colleagues, through: :route_colleagues, dependent: :destroy
      has_many :comments, as: :commentable, class_name: 'Messaging::CommentRecord'
      has_many :points, class_name: 'Training::Activities::MountainRoutePointRecord'
      has_many :training_contracts, class_name: 'Training::Activities::UserContractRecord', foreign_key: :route_id

      has_many :photos, as: :uploadable, class_name: 'Storage::UploadRecord'
      accepts_nested_attributes_for :photos, reject_if: proc { |attributes| attributes[:file].blank? }

      validates :name, :rating, :climbing_date, presence: true

      def save_boar_length
        if training
          self.boar_length = length / 2
        else
          self.boar_length = length
        end
      end

      def slug_candidates
        [
          [:climbing_date, :name],
          [:route_type, :climbing_date, :name]
        ]
      end

      def category
        return :sww if route_type.nil?

        case route_type.to_sym
        when :ski
          :snw
        when :trad_climbing
          :trad
        when :sport_climbing
          :sport
        else
          :sww
        end
      end

      def google_image_url
        decoded_summary_polyline = ::Polylines::Decoder.decode_polyline(map_summary_polyline)
        start_latlng = decoded_summary_polyline[0]
        end_latlng = decoded_summary_polyline[-1]

        google_maps_api_key = ENV.fetch('GOOGLE_STATIC_MAPS_API_KEY') { Rails.application.credentials.dig(:google, :static_maps_api_key) }

        "https://maps.googleapis.com/maps/api/staticmap?maptype=roadmap&path=enc:#{map_summary_polyline}&key=#{google_maps_api_key}&size=800x800&markers=color:yellow|label:S|#{start_latlng[0]},#{start_latlng[1]}&markers=color:green|label:F|#{end_latlng[0]},#{end_latlng[1]}"
      end

      def persons
        cn = colleagues.map(&:display_name)
        cn = cn.push(partners) if partners.present?
        cn.to_sentence
      end

      def colleagues_names=(ids)
        self.colleague_ids = ids
      end

      def primary_photo
        photos.first
      end

      attr_reader :colleagues_names
    end
  end
end
