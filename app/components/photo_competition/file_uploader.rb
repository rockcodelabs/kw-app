module PhotoCompetition
  class FileUploader < ApplicationUploader
    include CarrierWave::MiniMagick

    def extension_allowlist
      %w(jpg jpeg png)
    end

    version :thumb do
      process resize_to_fill: [100, 100]

      def store_dir
        "photo_competitions/#{model.edition.code}/thumbs/#{model.category.name.parameterize.underscore}"
      end
    end

    version :preview do
      process resize_to_fit: [1024, 1024]

      def store_dir
        "photo_competitions/#{model.edition.code}/preview/#{model.category.name.parameterize.underscore}"
      end
    end

    def store_dir
      "photo_competitions/#{model.edition.code}/#{model.category.name.parameterize.underscore}"
    end

    def filename
      if original_filename
        if model && model.read_attribute(mounted_as).present?
          model.read_attribute(mounted_as)
        else
          "#{secure_token}.#{file.extension}" if original_filename.present?
        end
      end
    end

    protected

    def secure_token
      var = :"@#{mounted_as}_secure_token"
      model.instance_variable_get(var) or model.instance_variable_set(var, SecureRandom.uuid)
    end
  end
end
