# frozen_string_literal: true

require 'rails_helper'

# The course page is the busiest screen of the module: sign-up form, limiter, packages, and (for organisers)
# the participant lists split by payment state. Every variant must render.
RSpec.describe 'Training::Supplementary::CoursesController#show', type: :request do
  let(:organizer) { create(:user, :with_events_role, :with_membership, :with_profile) }
  let(:member) { create(:user, :with_membership, :with_profile) }
  let(:repository) { Training::Supplementary::Repository.new }

  let!(:course) do
    Training::Supplementary::CourseRecord.create!(
      name: 'Kurs lodowy', place: 'Kraków', state: :published, payment_type: :trainings, price: true, price_kw: 150,
      organizator_id: organizer.id, start_date: 2.weeks.from_now, end_date: 2.weeks.from_now + 1.day
    )
  end

  def sign_up!(name:, email:, user_id: nil)
    repository.sign_up!(name: name, email: email, user_id: user_id, course_id: course.id, question: nil)
  end

  before { ActiveJob::Base.queue_adapter = :test }

  describe 'as an active member' do
    before { sign_in member }

    context 'when the course has a seat limit' do
      before { course.update!(open: false, limit: 5) }

      it 'shows the sign-up form for a course the member has not joined' do
        get "/wydarzenia/#{course.slug}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Kurs lodowy')
        expect(response.body).to include('action="/supplementary/sign_ups"')
        expect(response.body).to include('Zapisz się')
      end

      it 'offers the payment link once the sign-up has been sent to the member' do
        sign_up = sign_up!(name: member.display_name, email: member.email, user_id: member.id)
        sign_up.update!(sent_at: Time.current)

        get "/wydarzenia/#{course.slug}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("/payments/#{sign_up.payment.id}/charge")
        expect(response.body).not_to include('action="/supplementary/sign_ups"')
      end

      it 'does not offer the payment link before the sign-up has been sent to the member' do
        sign_up = sign_up!(name: member.display_name, email: member.email, user_id: member.id)

        get "/wydarzenia/#{course.slug}"

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("/payments/#{sign_up.payment.id}/charge")
      end

      it 'shows a prepaid member as signed up without a payment link' do
        sign_up = sign_up!(name: member.display_name, email: member.email, user_id: member.id)
        sign_up.update!(sent_at: Time.current)
        sign_up.payment.update!(state: 'prepaid')

        get "/wydarzenia/#{course.slug}"

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("/payments/#{sign_up.payment.id}/charge")
      end
    end

    it 'shows no sign-up form for an open event' do
      get "/wydarzenia/#{course.slug}"

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('action="/supplementary/sign_ups"')
    end

    it 'renders a course with packages and a question' do
      course.update!(packages: true, question: true)
      course.package_types.create!(name: 'Pakiet VIP', cost: 99)

      get "/wydarzenia/#{course.slug}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Pakiet VIP')
    end

    it 'renders a closed course whose limit is reached' do
      course.update!(open: false, limit: 1, end_application_date: 1.day.ago)
      sign_up!(name: 'Ktoś', email: 'ktos@example.com').payment.update!(state: 'prepaid')

      get "/wydarzenia/#{course.slug}"

      expect(response).to have_http_status(:ok)
    end

    it 'renders a course whose sign-ups have not started yet' do
      course.update!(application_date: 1.week.from_now)

      get "/wydarzenia/#{course.slug}"

      expect(response).to have_http_status(:ok)
    end

    it 'renders a cancelled and an archived course' do
      %i[cancelled archived].each do |state|
        course.update!(state: state)

        get "/wydarzenia/#{course.slug}"

        expect(response).to have_http_status(:ok)
      end
    end

    it 'renders a course without dates or organizer' do
      course.update_columns(start_date: nil, end_date: nil, organizator_id: nil)

      get "/wydarzenia/#{course.slug}"

      expect(response).to have_http_status(:ok)
    end

    it 'finds the course by numeric id as well as by slug' do
      get "/wydarzenia/#{course.id}"

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'as the organiser' do
    before { sign_in organizer }

    it 'renders the participant lists for every payment state' do
      course.update!(open: false, limit: 10)
      prepaid = sign_up!(name: 'Opłacony', email: 'oplacony@example.com')
      prepaid.payment.update!(state: 'prepaid')
      cash = sign_up!(name: 'Gotówka', email: 'gotowka@example.com')
      cash.payment.update!(state: 'prepaid', cash: true, cash_user_id: organizer.id)
      sign_up!(name: 'Nieopłacony', email: 'nieoplacony@example.com')
      refunded = sign_up!(name: 'Zwrócony', email: 'zwrocony@example.com')
      refunded.payment.update!(state: 'prepaid', refunded_at: Time.current)
      sign_up!(name: 'Członek', email: member.email, user_id: member.id)

      get "/wydarzenia/#{course.slug}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Opłacony', 'Gotówka', 'Nieopłacony')
    end

    it 'renders the participant lists for a course with packages' do
      course.update!(packages: true)
      package = course.package_types.create!(name: 'Pakiet VIP', cost: 99)
      sign_up!(name: 'Z pakietem', email: 'pakiet@example.com').update!(supplementary_course_package_type_id: package.id)

      get "/wydarzenia/#{course.slug}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Pakiet VIP')
    end

    it 'exports every participant to xlsx, with their payment state' do
      sign_up!(name: 'Opłacony', email: 'oplacony@example.com').payment.update!(state: 'prepaid')
      sign_up!(name: 'Nieopłacony', email: 'nieoplacony@example.com')

      get "/supplementary/courses/#{course.id}.xlsx"

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to include('spreadsheet')
      expect(response.body.bytesize).to be > 1000
    end

    it 'shows the admin list grouped by state' do
      draft = Training::Supplementary::CourseRecord.create!(name: 'Szkic', place: 'X', state: :draft, payment_type: :trainings)
      Training::Supplementary::CourseRecord.create!(name: 'Stary', place: 'X', state: :archived, payment_type: :trainings,
                                                    start_date: 1.year.ago)

      get '/supplementary/courses'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Kurs lodowy', draft.name)
    end

    it 'filters the list by category and kind' do
      get '/supplementary/courses', params: { category: 'kw', kind: 'training' }

      expect(response).to have_http_status(:ok)
    end

    it 'prefills the new form from a duplicated course' do
      get new_supplementary_course_path, params: { dup: 1, course: { name: 'Kopia kursu', place: 'Kraków', payment_type: 'trainings' } }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Kopia kursu')
    end

    it 'creates a course together with its packages' do
      expect do
        post supplementary_courses_path, params: {
          course: {
            name: 'Kurs z pakietami', place: 'Tatry', payment_type: 'trainings', packages: '1',
            organizator_id: organizer.id.to_s,
            package_types_attributes: { '0' => { name: 'Podstawowy', cost: '100' }, '1' => { name: 'Pełny', cost: '200' } }
          }
        }
      end.to change(Training::Supplementary::CourseRecord, :count).by(1)

      created = Training::Supplementary::CourseRecord.find_by(name: 'Kurs z pakietami')
      expect(created.package_types.map(&:name)).to contain_exactly('Podstawowy', 'Pełny')
      expect(created).to be_packages
    end
  end
end
