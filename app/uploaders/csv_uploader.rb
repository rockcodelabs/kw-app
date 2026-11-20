class CsvUploader < CarrierWave::Uploader::Base
  storage :file

  def store_dir
    "uploads/csv/#{mounted_as}"
  end

  def extension_allowlist
    %w(csv)
  end
end
