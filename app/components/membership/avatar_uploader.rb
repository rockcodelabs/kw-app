module Membership
  class AvatarUploader < ApplicationUploader
    include CarrierWave::MiniMagick

    def extension_allowlist
      IMAGE_EXTENSIONS
    end

    process resize_to_limit: [250, 250]

    def default_url(*args)
      ActionController::Base.helpers.image_url('default-avatar.png')
    end

    def store_dir
      "membership/avatars/#{model.id}"
    end
  end
end
