module Management
  class ProjectsController < ApplicationController
    include EitherMatcher
    append_view_path 'app/components'

    def index
      authorize! :read, Management::ProjectRecord

      @projects = Management::ProjectRecord.includes(:users).order(created_at: :desc)
    end

    def new
      @project = Management::ProjectRecord.new
      authorize! :manage, @project
      @users = []
    end

    def create
      authorize! :manage, Management::ProjectRecord

      either(create_record) do |result|
        result.success do
          redirect_to projects_path, flash: { notice: 'Utworzono projekt' }
        end

        result.failure do |errors|
          @project = Management::ProjectRecord.new(project_params)
          @users = @project.users.map { |u| { name: u.display_name, id: u.id} }
          @errors = errors.map { |field, messages| "#{Management::ProjectRecord.human_attribute_name(field)} #{messages.to_sentence}" }
          render :new
        end
      end
    end

    def show
      authorize! :read, @project

      @project = Management::ProjectRecord.friendly.find(params[:id])
    end

    def edit
      @project = Management::ProjectRecord.friendly.find(params[:id])
      authorize! :manage, @project
      @users = @project.users.map { |u| { name: u.display_name, id: u.id} }
    end

    def update
      @project = Management::ProjectRecord.new(project_params)
      authorize! :manage, @project

      either(update_record) do |result|
        result.success do |project|
          redirect_to project_path(project), flash: { notice: 'Zaktualizowano projekt' }
        end

        result.failure do |errors|
          @project = Management::ProjectRecord.find(params[:id])
          @project.assign_attributes(project_params.except(:attachments, :users_names))
          @users = @project.users.map { |u| { name: u.display_name, id: u.id} }
          @errors = errors.map { |field, messages| "#{Management::ProjectRecord.human_attribute_name(field)} #{messages.to_sentence}" }
          render :edit
        end
      end
    end

    def destroy
      project = Management::ProjectRecord.friendly.find(params[:id])
      authorize! :manage, @project
      project.destroy

      redirect_to projects_path, notice: 'Usunięto'
    end

    private

    def create_record
      Management::CreateProject.new(
        Management::ProjectForm
      ).call(raw_inputs: project_params)
    end

    def update_record
      Management::UpdateProject.new(
        Management::ProjectForm
      ).call(id: params[:id], raw_inputs: project_params)
    end

    def project_params
      params
        .require(:project)
        .permit(:name, :description, :know_how, :estimated_time, :benefits, :state, :needed_knowledge, users_names: [], attachments: [])
    end
  end
end
