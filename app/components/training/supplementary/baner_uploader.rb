module Training
  module Supplementary
    class BanerUploader < ApplicationUploader
      include CarrierWave::MiniMagick

      def extension_allowlist
        IMAGE_EXTENSIONS
      end

      process resize_to_limit: [1200, -1]

      def store_dir
        "uploads/courses/#{model.id}/#{mounted_as}"
      end
    end
  end
end
