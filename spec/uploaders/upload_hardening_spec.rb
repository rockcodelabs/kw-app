# frozen_string_literal: true

require 'rails_helper'

# G9 (docs/NEW_PRODUCTION_PLAN.md): old prod accepted arbitrary extensions (8 .php probe files sat in the upload
# cache) and cached uploads under public/, where the app serves them. The cache now lives in tmp/ and every
# uploader has an extension allowlist, narrowed to images where only images make sense.
RSpec.describe 'Upload hardening' do
  def file_named(name)
    CarrierWave::SanitizedFile.new(tempfile: StringIO.new('x'), filename: name)
  end

  def accepts?(uploader, name)
    uploader.send(:check_extension_allowlist!, file_named(name))
    true
  rescue CarrierWave::IntegrityError
    false
  end

  # Extensions found on staging (a restored copy of prod data) in every mounted uploader column on 2026-11-18.
  stored_in_production = %w[jpg jpeg jfif png gif webp heic bmp tif pdf doc docx xls xlsx odt ods rtf txt gpx tcx eml mp4 mov]
  dangerous = %w[php phtml php5 html htm svg js exe sh bat jsp asp aspx cgi pl py htaccess]

  image_only = [
    Membership::AvatarUploader,
    Events::Competitions::BanerUploader,
    Training::Supplementary::BanerUploader,
    Settlement::ContractorLogoUploader,
    Reservations::PhotoUploader,
    PhotoCompetition::FileUploader
  ]

  uploader_files = Dir[Rails.root.join('app/{uploaders,components}/**/*uploader.rb')]
  all_uploaders = uploader_files.filter_map do |path|
    root = path.include?('/app/uploaders/') ? 'app/uploaders/' : 'app/components/'
    name = path.split(root, 2).last.delete_suffix('.rb').camelize
    klass = name.constantize
    klass if klass < ApplicationUploader
  end

  it 'finds the application uploaders' do
    expect(all_uploaders.size).to be > 15
    expect(all_uploaders).to include(AttachmentUploader, Storage::FileUploader, Training::Activities::GpsTrackUploader)
  end

  describe 'extension allowlist on every uploader' do
    all_uploaders.each do |klass|
      context klass.name do
        let(:uploader) { klass.new }

        it 'has an allowlist' do
          expect(uploader.extension_allowlist).to be_present
        end

        dangerous.each do |extension|
          it "rejects .#{extension}, also in upper case" do
            expect(accepts?(uploader, "upload.#{extension}")).to be(false)
            expect(accepts?(uploader, "UPLOAD.#{extension.upcase}")).to be(false)
          end
        end

        it 'rejects files without an extension' do
          expect(accepts?(uploader, 'upload')).to be(false)
        end

        it 'accepts a regular photo' do
          expect(accepts?(uploader, 'photo.JPG')).to be(true)
        end
      end
    end
  end

  describe 'ApplicationUploader' do
    stored_in_production.each do |extension|
      it "still accepts .#{extension}, which production data contains" do
        expect(accepts?(ApplicationUploader.new, "file.#{extension}")).to be(true)
      end
    end
  end

  describe 'image-only uploaders' do
    image_only.each do |klass|
      it "#{klass.name} accepts images and rejects documents and tracks" do
        expect(accepts?(klass.new, 'a.png')).to be(true)
        %w[pdf docx xlsx gpx eml mp4 txt].each do |extension|
          expect(accepts?(klass.new, "a.#{extension}")).to be(false), "#{klass.name} accepted .#{extension}"
        end
      end
    end
  end

  describe CsvUploader do
    it 'accepts only csv' do
      expect(accepts?(described_class.new, 'import.csv')).to be(true)
      expect(accepts?(described_class.new, 'import.php')).to be(false)
    end
  end

  describe 'cache directory' do
    it 'is outside public/, so cached uploads are never served' do
      cache_dir = Pathname.new(ApplicationUploader.new.cache_dir)
      expect(cache_dir).to eq(Rails.root.join('tmp/uploads'))
      expect(cache_dir.to_s).not_to start_with(Rails.root.join('public').to_s)
    end
  end
end
