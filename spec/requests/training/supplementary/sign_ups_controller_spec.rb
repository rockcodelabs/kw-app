# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Training::Supplementary::SignUpsController', type: :request do
  let(:member) { create(:user, :with_membership, :with_profile) }
  let(:admin) { create(:user, :admin) }
  let!(:course) { Training::Supplementary::CourseRecord.create!(name: 'Kurs', place: 'Kraków', state: :published, send_manually: true) }

  def sign_up_params(overrides = {})
    { sign_up: { name: 'Jan Kowalski', email: 'jan@example.com', course_id: course.id }.merge(overrides) }
  end

  describe 'POST create' do
    it 'signs up an anonymous participant' do
      expect { post supplementary_sign_ups_path, params: sign_up_params }
        .to change(Training::Supplementary::SignUpRecord, :count).by(1)

      expect(flash[:notice]).to eq('Zapisałeś się!')
    end

    it 'signs up a member' do
      sign_in member

      expect { post supplementary_sign_ups_path, params: sign_up_params(user_id: member.id, email: member.email) }
        .to change(Training::Supplementary::SignUpRecord, :count).by(1)

      expect(Training::Supplementary::SignUpRecord.last.user_id).to eq(member.id)
    end

    it 'fails when the name is missing' do
      expect { post supplementary_sign_ups_path, params: sign_up_params(name: '') }
        .not_to change(Training::Supplementary::SignUpRecord, :count)

      expect(flash[:error]).to eq('Imię i nazwisko musi być wypełnione')
    end

    it 'fails when the course asks a question and none was given' do
      course.update!(question: true)

      expect { post supplementary_sign_ups_path, params: sign_up_params }
        .not_to change(Training::Supplementary::SignUpRecord, :count)

      expect(flash[:error]).to include('musi zostać wypełniona')
    end

    it 'accepts the answer when the course asks a question' do
      course.update!(question: true)

      expect { post supplementary_sign_ups_path, params: sign_up_params(question: 'Tak') }
        .to change(Training::Supplementary::SignUpRecord, :count).by(1)
    end

    it 'requires a package when the course has packages' do
      course.update!(packages: true)

      expect { post supplementary_sign_ups_path, params: sign_up_params }
        .not_to change(Training::Supplementary::SignUpRecord, :count)

      expect(flash[:error]).to include('musi zostać wybrany')
    end

    it 'rejects a duplicated e-mail' do
      post supplementary_sign_ups_path, params: sign_up_params

      expect { post supplementary_sign_ups_path, params: sign_up_params }
        .not_to change(Training::Supplementary::SignUpRecord, :count)

      expect(flash[:error]).to include('Ten e-mail jest już zapisany!')
    end
  end

  describe 'PUT update' do
    let!(:sign_up) do
      Training::Supplementary::SignUpRecord.create!(name: 'Jan', email: 'jan@example.com', course_id: course.id, code: 'abc')
    end

    it 'updates the sign up' do
      sign_in admin

      put supplementary_sign_up_path(sign_up), params: sign_up_params(name: 'Nowe Imie')

      expect(flash[:notice]).to eq('Zaktualizowałeś!')
      expect(sign_up.reload.name).to eq('Nowe Imie')
    end

    it 'fails with a flash error on invalid data' do
      sign_in admin

      put supplementary_sign_up_path(sign_up), params: sign_up_params(name: '')

      expect(flash[:error]).to include('musi być wypełnione')
      expect(sign_up.reload.name).to eq('Jan')
    end
  end

  describe 'PUT manually' do
    before { sign_in admin }

    let(:manual_params) do
      { manually_sign_up: { email: 'reczny@example.com', course_id: course.id, link_payment: '0' } }
    end

    it 'signs a participant up' do
      expect { put manually_supplementary_sign_ups_path, params: manual_params }
        .to change(Training::Supplementary::SignUpRecord, :count).by(1)

      expect(Training::Supplementary::SignUpRecord.last).to have_attributes(email: 'reczny@example.com', course_id: course.id)
    end

    it 'fails when the e-mail is missing' do
      manual_params[:manually_sign_up][:email] = ''

      expect { put manually_supplementary_sign_ups_path, params: manual_params }
        .not_to change(Training::Supplementary::SignUpRecord, :count)

      expect(flash[:error]).to include('musi być wypełnione')
    end
  end
end
