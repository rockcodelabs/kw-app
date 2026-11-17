# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Training::Supplementary::PackagesController', type: :request do
  let(:admin) { create(:user, :admin) }
  let!(:course) { Training::Supplementary::CourseRecord.create!(name: 'Kurs', place: 'Kraków', packages: true) }

  describe 'POST create' do
    before { sign_in admin }

    it 'creates a package' do
      expect do
        post supplementary_course_packages_path(course), params: { package: { name: 'Pakiet', cost: '100', course_id: course.id } }
      end.to change(Training::Supplementary::PackageTypeRecord, :count).by(1)

      expect(flash[:notice]).to eq('Dodałeś pakiet!')
    end

    it 'fails with a flash error when the name is missing' do
      expect do
        post supplementary_course_packages_path(course), params: { package: { name: '', cost: '100', course_id: course.id } }
      end.not_to change(Training::Supplementary::PackageTypeRecord, :count)

      expect(flash[:error]).to include('musi być wypełnione')
    end
  end
end
