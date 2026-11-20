module Events
  module Competitions
    class BanerUploader < ApplicationUploader
      include CarrierWave::MiniMagick

      def extension_allowlist
        IMAGE_EXTENSIONS
      end

      process resize_to_limit: [1200, -1]

      def store_dir
        "competitions/baners/#{model.id}"
      end
    end
  end
end
