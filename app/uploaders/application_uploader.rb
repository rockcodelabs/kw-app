# Base uploader class for all CarrierWave uploaders
# Uses cloud storage (OpenStack) for all environments
#
# Automatically detects and stores MIME type on upload to avoid reading
# file content from OpenStack on every page render (which causes EOFError)
class ApplicationUploader < CarrierWave::Uploader::Base
  IMAGE_EXTENSIONS = %w[jpg jpeg jfif png gif webp heic heif bmp tif tiff].freeze
  # Everything members and admins upload today (checked against the restored production data), nothing executable
  # or renderable as a page (no html, svg, js, php, archives).
  ALLOWED_EXTENSIONS = (IMAGE_EXTENSIONS + %w[pdf doc docx xls xlsx odt ods rtf txt gpx tcx eml mp4 mov]).freeze

  # Always use cloud storage
  storage :fog

  # Override with IMAGE_EXTENSIONS (or another narrower list) in uploaders that only take one kind of file.
  def extension_allowlist
    ALLOWED_EXTENSIONS
  end
  
  # Automatically detect and store content type after upload
  # This prevents EOFError by avoiding file reads during rendering
  after :store, :save_content_type_to_model
  
  def save_content_type_to_model(file)
    # Only save if model responds to content_type= (like Storage::UploadRecord)
    return unless model.respond_to?(:content_type=)
    return if model.content_type.present? # Skip if already set
    
    begin
      # Detect MIME type from file path (extension-based, fast)
      mime = MimeMagic.by_path(file.path)
      
      if mime
        model.content_type = mime.type
        model.save if model.persisted?
        Rails.logger.info "[ApplicationUploader] Saved content_type '#{mime.type}' for #{model.class.name}##{model.id}"
      else
        # Fallback: detect from file extension
        extension = File.extname(file.path).downcase.delete('.')
        fallback_type = content_type_from_extension(extension)
        model.content_type = fallback_type if fallback_type
        model.save if model.persisted?
        Rails.logger.info "[ApplicationUploader] Saved fallback content_type '#{fallback_type}' for #{model.class.name}##{model.id}"
      end
    rescue => e
      Rails.logger.error "[ApplicationUploader] Failed to save content_type for #{model.class.name}##{model.id}: #{e.message}"
    end
  end
  
  private
  
  # Fallback content type detection based on file extension
  def content_type_from_extension(extension)
    case extension
    when 'jpg', 'jpeg' then 'image/jpeg'
    when 'png' then 'image/png'
    when 'gif' then 'image/gif'
    when 'webp' then 'image/webp'
    when 'pdf' then 'application/pdf'
    when 'doc' then 'application/msword'
    when 'docx' then 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
    when 'xls' then 'application/vnd.ms-excel'
    when 'xlsx' then 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    when 'zip' then 'application/zip'
    when 'txt' then 'text/plain'
    when 'gpx' then 'application/gpx+xml'
    else nil
    end
  end
  
  public
  
  # Check if file exists in Fog storage
  # CarrierWave's blank? method incorrectly returns true for Fog files
  # because it checks file.size which returns 0 for lazy-loaded Fog objects
  # Use this method instead of !blank? when checking if Fog files exist
  def fog_present?
    url.present?
  end
end