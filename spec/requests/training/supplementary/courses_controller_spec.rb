# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Training::Supplementary::CoursesController', type: :request do
  let(:admin) { create(:user, :admin, :with_membership, :with_profile) }
  let(:events_user) { create(:user, :with_events_role, :with_membership, :with_profile) }
  let(:member) { create(:user, :with_membership, :with_profile) }

  let!(:course) do
    Training::Supplementary::CourseRecord.create!(
      name: 'Kurs lodowy', place: 'Kraków', state: :published, payment_type: :trainings,
      price_kw: 100, start_date: 2.weeks.from_now, end_date: 2.weeks.from_now + 1.day
    )
  end

  let(:valid_params) do
    { course: { name: 'Nowy kurs', place: 'Tatry', payment_type: 'trainings', kind: 'training', category: 'kw', state: 'draft' } }
  end

  # Finding G24: CoursesController has no authenticate/authorize on create, edit, update and destroy.
  # Remove the pending flag once the controller authorizes these actions.
  PENDING_AUTHZ = 'G24: courses create/update/destroy are not authorized'

  before { ActiveJob::Base.queue_adapter = :test }

  describe 'event pages for an active member' do
    before { sign_in member }

    it 'lists events on /wydarzenia' do
      get '/wydarzenia'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Kurs lodowy')
    end

    it 'shows a course page by slug' do
      get "/wydarzenia/#{course.slug}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Kurs lodowy')
    end

    it 'redirects with an alert for an unknown slug' do
      get '/wydarzenia/does-not-exist'

      expect(response).to have_http_status(:redirect)
      expect(flash[:alert]).to be_present
    end

    it 'renders the archived list' do
      get archived_supplementary_courses_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'event pages for anonymous visitors' do
    it 'redirects instead of raising' do
      get '/wydarzenia'

      expect(response).to have_http_status(:redirect)
    end
  end

  describe 'admin management' do
    before { sign_in admin }

    it 'renders the admin list, new and edit forms' do
      get supplementary_courses_path
      expect(response).to have_http_status(:ok)

      get new_supplementary_course_path
      expect(response).to have_http_status(:ok)

      get edit_supplementary_course_path(course)
      expect(response).to have_http_status(:ok)
    end

    it 'creates a course and redirects to /wydarzenia' do
      expect { post supplementary_courses_path, params: valid_params }
        .to change(Training::Supplementary::CourseRecord, :count).by(1)

      expect(response).to redirect_to(wydarzenia_path)
      expect(flash[:notice]).to eq('Utworzono wydarzenie')
    end

    it 're-renders the form when required fields are missing' do
      expect { post supplementary_courses_path, params: { course: { name: '', place: '', payment_type: 'trainings' } } }
        .not_to change(Training::Supplementary::CourseRecord, :count)

      expect(response).to have_http_status(:ok)
    end

    it 'updates a course and writes a PaperTrail version' do
      expect do
        patch supplementary_course_path(course), params: { course: { name: 'Zmieniona nazwa' } }
      end.to change { course.reload.versions.count }.by(1)

      expect(course.name).to eq('Zmieniona nazwa')
      expect(flash[:notice]).to eq('Course updated')
    end

    %w[draft published cancelled archived].each do |state|
      it "moves a course to #{state}" do
        patch supplementary_course_path(course), params: { course: { state: state } }

        expect(course.reload.state).to eq(state)
      end
    end

    it 'destroys a course' do
      expect { delete supplementary_course_path(course) }
        .to change(Training::Supplementary::CourseRecord, :count).by(-1)
    end

    it 'exports the sign-up list as xlsx' do
      get "/supplementary/courses/#{course.id}.xlsx"

      expect(response).to have_http_status(:ok)
      expect(response.headers['Content-Disposition']).to include('.xlsx')
    end
  end

  describe 'authorization' do
    it 'does not let anonymous visitors create a course', pending: PENDING_AUTHZ do
      expect { post supplementary_courses_path, params: valid_params }
        .not_to change(Training::Supplementary::CourseRecord, :count)
    end

    it 'does not let anonymous visitors change a course', pending: PENDING_AUTHZ do
      patch supplementary_course_path(course), params: { course: { name: 'Zhakowane' } }

      expect(course.reload.name).to eq('Kurs lodowy')
    end

    it 'does not let anonymous visitors destroy a course', pending: PENDING_AUTHZ do
      expect { delete supplementary_course_path(course) }
        .not_to change(Training::Supplementary::CourseRecord, :count)
    end

    it 'does not let a plain member change a course', pending: PENDING_AUTHZ do
      sign_in member

      patch supplementary_course_path(course), params: { course: { name: 'Zhakowane' } }

      expect(course.reload.name).to eq('Kurs lodowy')
    end

    it 'does not let a plain member destroy a course', pending: PENDING_AUTHZ do
      sign_in member

      expect { delete supplementary_course_path(course) }
        .not_to change(Training::Supplementary::CourseRecord, :count)
    end

    it 'lets a user with the events role change a course' do
      sign_in events_user

      patch supplementary_course_path(course), params: { course: { name: 'Zmiana przez events' } }

      expect(course.reload.name).to eq('Zmiana przez events')
    end
  end
end
