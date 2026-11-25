# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Homepage "Najlepsze przejścia" photos', type: :request do
  let(:member) { create(:user, :with_membership, :with_profile) }
  let(:route) { create(:mountain_route) }

  before { sign_in member }

  # Non-image uploads (and seed files) get no :thumb version, so thumb.url is nil.
  it 'does not crash when the primary photo has no thumbnail' do
    photo = Storage::UploadRecord.new(uploadable: route, content_type: 'application/octet-stream')
    photo[:file] = 'test.jpeg'
    photo.save!(validate: false)
    expect(route.reload.primary_photo.file.thumb.url).to be_blank

    get '/'

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Najlepsze przejścia')
  end
end
