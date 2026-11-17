# frozen_string_literal: true

module Training
  module Activities
    class SkiRouteForm < Dry::Validation::Contract
      config.messages.load_paths << 'app/components/training/errors.yml'
      config.messages.namespace = :ski_route

      params do
        required(:name).filled(:string)
        required(:climbing_date).filled
        required(:colleague_ids).filled
        optional(:rating).filled
        optional(:partners)
        optional(:photograph)
        optional(:difficulty)
        optional(:area)
        optional(:length)
        optional(:description)
        optional(:contract_ids)
        optional(:attachments)
        optional(:photos_attributes)
        optional(:gps_tracks)
        optional(:training)
        optional(:hidden)
      end

      rule(:gps_tracks) do
        tracks = Array(value).reject(&:blank?)
        key.failure(:gps_tracks_extension) unless tracks.all? { |track| File.extname(track.original_filename.to_s) == '.gpx' }
      end
    end
  end
end
