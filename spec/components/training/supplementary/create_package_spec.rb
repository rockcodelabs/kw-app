# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Training::Supplementary::CreatePackage do
  subject(:service) { described_class.new(Training::Supplementary::Repository.new, Training::Supplementary::CreatePackageForm.new) }

  let!(:course) { Training::Supplementary::CourseRecord.create!(name: 'Kurs', place: 'Kraków', state: :published) }

  it 'creates a package for the course' do
    result = service.call(raw_inputs: { name: 'Pakiet', cost: '100', course_id: course.id.to_s })

    expect(result).to eq(Dry::Monads::Success(:success))
    expect(course.reload.package_types).to contain_exactly(have_attributes(name: 'Pakiet', cost: 100))
  end

  it 'returns full Polish messages on invalid input' do
    result = service.call(raw_inputs: { name: '', cost: '100', course_id: course.id.to_s })

    expect(result).to be_failure
    expect(result.failure[:name]).to eq(['name musi być wypełnione'])
  end

  it 'does not create anything on invalid input' do
    expect { service.call(raw_inputs: { name: '', cost: '', course_id: '' }) }
      .not_to change(Training::Supplementary::PackageTypeRecord, :count)
  end
end
