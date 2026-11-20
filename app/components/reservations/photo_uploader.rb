module Reservations
  class PhotoUploader < ApplicationUploader
    include CarrierWave::MiniMagick

    def extension_allowlist
      IMAGE_EXTENSIONS
    end

    version :thumb do
      process resize_to_fill: [180, 180]
    end

    def store_dir
      "reservations/photos/#{model.id}"
    end
  end
end
