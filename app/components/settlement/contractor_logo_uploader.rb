module Settlement
  class ContractorLogoUploader < ApplicationUploader
    include CarrierWave::MiniMagick

    def extension_allowlist
      IMAGE_EXTENSIONS
    end

    version :thumb do
      process resize_to_fill: [180, 180]
    end

    def filename
      "#{model.name}.#{file.extension}" if original_filename.present?
    end

    def store_dir
      "contractors/#{model.name}"
    end
  end
end
