require 'rails_helper'

RSpec.describe Training::Supplementary::CreateCourse do
  let(:repository) { Training::Supplementary::Repository.new }
  let(:form_class) { Training::Supplementary::CreateCourseForm }
  let(:service) { described_class.new(repository, form_class) }

  describe '#call' do
    context 'when form validation fails' do
      it 'returns Failure when required fields are missing' do
        raw_inputs = {
          name: '',
          place: '',
          payment_type: ''
        }

        result = service.call(raw_inputs: raw_inputs)

        expect(result).to be_failure
        expect(result.failure).to be_a(Hash)
        expect(result.failure).to be_present
      end

      it 'returns Failure when name is missing' do
        raw_inputs = {
          name: '',
          place: 'Kraków',
          payment_type: 'trainings'
        }

        result = service.call(raw_inputs: raw_inputs)

        expect(result).to be_failure
        expect(result.failure[:name]).to be_present
      end

      it 'returns Failure when place is missing' do
        raw_inputs = {
          name: 'Test Course',
          place: '',
          payment_type: 'trainings'
        }

        result = service.call(raw_inputs: raw_inputs)

        expect(result).to be_failure
        expect(result.failure[:place]).to be_present
      end

      it 'returns Failure when payment_type is missing' do
        raw_inputs = {
          name: 'Test Course',
          place: 'Kraków',
          payment_type: ''
        }

        result = service.call(raw_inputs: raw_inputs)

        expect(result).to be_failure
        expect(result.failure[:payment_type]).to be_present
      end
    end

    context 'when form validation passes' do
      it 'creates a course with required fields only' do
        raw_inputs = {
          name: 'Test Course',
          place: 'Kraków',
          payment_type: 'trainings'
        }

        result = service.call(raw_inputs: raw_inputs)

        expect(result).to be_success
        
        created_course = Training::Supplementary::CourseRecord.last
        expect(created_course.name).to eq('Test Course')
        expect(created_course.place).to eq('Kraków')
        expect(created_course.payment_type).to eq('trainings')
      end

      it 'creates a course with full set of attributes' do
        raw_inputs = {
          name: 'Advanced Training',
          place: 'Zakopane',
          payment_type: 'club_trips',
          category: 'snw',
          state: 'published',
          kind: 'training',
          baner_type: 'baner_ski',
          email_remarks: 'Please bring your own equipment',
          paid_email: 'Thank you for payment',
          remarks: 'Additional notes',
          send_manually: true,
          expired_hours: 48,
          limit: 20,
          price_kw: 100,
          price_non_kw: 150,
          price: true,
          one_day: false,
          packages: true,
          cash: true,
          reserve_list: true,
          open: true,
          active: true,
          last_fee_paid: false
        }

        result = service.call(raw_inputs: raw_inputs)

        expect(result).to be_success
        
        created_course = Training::Supplementary::CourseRecord.last
        expect(created_course.name).to eq('Advanced Training')
        expect(created_course.place).to eq('Zakopane')
        expect(created_course.payment_type).to eq('club_trips')
        expect(created_course.category).to eq('snw')
        expect(created_course.state).to eq('published')
        expect(created_course.kind).to eq('training')
        expect(created_course.email_remarks).to eq('Please bring your own equipment')
        expect(created_course.paid_email).to eq('Thank you for payment')
        expect(created_course.expired_hours).to eq(48)
        expect(created_course.limit).to eq(20)
        expect(created_course.price_kw).to eq(100)
        expect(created_course.price_non_kw).to eq(150)
      end

      it 'creates a course with packages posted the way the Rails nested form sends them (index-keyed hash)' do
        raw_inputs = {
          name: 'Kurs z pakietami',
          place: 'Tatry',
          payment_type: 'trainings',
          packages: '1',
          package_types_attributes: {
            '0' => { 'name' => 'Podstawowy', 'cost' => '100' },
            '1' => { 'name' => 'Pełny', 'cost' => '200' }
          }
        }

        result = service.call(raw_inputs: raw_inputs)

        expect(result).to be_success
        created_course = Training::Supplementary::CourseRecord.find_by!(name: 'Kurs z pakietami')
        expect(created_course.package_types.map(&:name)).to contain_exactly('Podstawowy', 'Pełny')
        expect(created_course).to be_packages
      end

      it 'creates a course with date fields' do
        raw_inputs = {
          name: 'Scheduled Course',
          place: 'Tatry',
          payment_type: 'trainings',
          start_date: '2025-06-01 10:00:00',
          end_date: '2025-06-05 16:00:00',
          application_date: '2025-05-01 00:00:00',
          end_application_date: '2025-05-25 23:59:59'
        }

        result = service.call(raw_inputs: raw_inputs)

        expect(result).to be_success
        
        created_course = Training::Supplementary::CourseRecord.last
        expect(created_course.start_date).to be_present
        expect(created_course.end_date).to be_present
        expect(created_course.application_date).to be_present
        expect(created_course.end_application_date).to be_present
      end

      it 'creates a course with organizer' do
        organizer = create(:user)
        
        raw_inputs = {
          name: 'Organized Course',
          place: 'Kraków',
          payment_type: 'trainings',
          organizator_id: organizer.id
        }

        result = service.call(raw_inputs: raw_inputs)

        expect(result).to be_success
        
        created_course = Training::Supplementary::CourseRecord.last
        expect(created_course.organizator_id).to eq(organizer.id)
        expect(created_course.organizer).to eq(organizer)
      end

      it 'creates a course with default state as draft' do
        raw_inputs = {
          name: 'New Course',
          place: 'Test Location',
          payment_type: 'trainings'
        }

        result = service.call(raw_inputs: raw_inputs)

        expect(result).to be_success
        
        created_course = Training::Supplementary::CourseRecord.last
        expect(created_course.state).to eq('draft')
      end

      it 'creates a course with default category as kw' do
        raw_inputs = {
          name: 'Another Course',
          place: 'Some Place',
          payment_type: 'trainings'
        }

        result = service.call(raw_inputs: raw_inputs)

        expect(result).to be_success
        
        created_course = Training::Supplementary::CourseRecord.last
        expect(created_course.category).to eq('kw')
      end
    end
  end
end