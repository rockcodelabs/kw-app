# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Management::ProjectsController', type: :request do
  let(:manager) { create(:user, :with_membership, :with_profile, roles: ['projects']) }

  before { sign_in manager }

  describe 'POST create' do
    it 'creates a project' do
      expect { post projects_path, params: { project: { name: 'Nowy projekt', description: 'Opis' } } }
        .to change(Management::ProjectRecord, :count).by(1)

      expect(response).to redirect_to(projects_path)
    end

    it 're-renders the form with a message when the name is missing' do
      expect { post projects_path, params: { project: { name: '' } } }
        .not_to change(Management::ProjectRecord, :count)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('musi być wypełnione')
    end
  end

  describe 'PUT update' do
    let!(:project) { Management::ProjectRecord.create!(name: 'Stary', state: 'draft') }

    it 'updates the project' do
      put project_path(project.id), params: { project: { name: 'Nowy', state: 'in_progress' } }

      expect(response).to redirect_to(project_path(project.reload))
      expect(project).to have_attributes(name: 'Nowy', state: 'in_progress')
    end

    it 're-renders the form when the name is blank' do
      put project_path(project.id), params: { project: { name: '' } }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('musi być wypełnione')
      expect(project.reload.name).to eq('Stary')
    end
  end
end
