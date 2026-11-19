module Training
  module Supplementary
    class CoursesController < ApplicationController
      respond_to :html, :xlsx
      include Dry::Monads[:result]
      append_view_path 'app/components'

      def index
        authorize! :index, Training::Supplementary::CourseRecord
        
        @active_courses = Training::Supplementary::Repository.new.fetch_active_courses(category: params[:category], kind: params[:kind])
        @draft_courses = Training::Supplementary::Repository.new.fetch_draft_courses(category: params[:category], kind: params[:kind])
        @inactive_courses = Training::Supplementary::Repository.new.fetch_inactive_courses(category: params[:category], kind: params[:kind])
        @archived_courses = Kaminari.paginate_array(Training::Supplementary::Repository.new.fetch_archived_courses(category: params[:category], kind: params[:kind])).page(params[:page]).per(5)
      end

      def archived
        @archived_courses = Kaminari.paginate_array(Training::Supplementary::Repository.new.fetch_archived_courses(category: params[:category], kind: params[:kind])).page(params[:page]).per(10)
      end

      def new
        authorize! :create, Training::Supplementary::CourseRecord

        if params[:dup]
          @course = Training::Supplementary::CourseRecord.new(course_params)
        else
          @course = Training::Supplementary::CourseRecord.new
        end
        @course.organizator_id = current_user.id
      end

      def show
        authorize! :read, Training::Supplementary::CourseRecord
        
        record = Training::Supplementary::CourseRecord.friendly.find(params[:id]) rescue Training::Supplementary::CourseRecord.find_by!(slug: params[:id])
        @course = Training::Supplementary::Course.from_record(record)
        @limiter = Training::Supplementary::Limiter.new(@course)
        @current_user_sign_up = Training::Supplementary::SignUpRecord.includes([:emails, :user]).find_by(course_id: @course.id, user_id: current_user.id) if user_signed_in?

        respond_with do |format|
          format.html
          format.xlsx do
            disposition = "attachment; filename=#{@course.slug[0..30]}_#{Time.now.strftime("%Y-%m-%d-%H%M%S")}.xlsx"
            response.headers['Content-Disposition'] = disposition
          end
        end
      end

      def edit
        @course = Training::Supplementary::CourseRecord.friendly.find(params[:id])
        authorize! :update, @course
      end

      def create
        authorize! :create, Training::Supplementary::CourseRecord

        case create_record
        in Success()
          redirect_to wydarzenia_path, flash: { notice: 'Utworzono wydarzenie' }
        in Failure(errors)
          @course = Training::Supplementary::CourseRecord.new(course_params)
          @errors = errors.map do |field, messages|
            field_name = Training::Supplementary::CourseRecord.human_attribute_name(field)
            messages.map { |msg| "#{field_name} #{msg}" }
          end.flatten
          render :new
        end
      end

      def update
        @course = Training::Supplementary::CourseRecord.friendly.find(params[:id])
        authorize! :update, @course

        if @course.update(course_params)
          redirect_to edit_supplementary_course_path(@course.id), notice: 'Course updated'
        else
          render :edit
        end
      end

      def destroy
        @course = Training::Supplementary::CourseRecord.friendly.find(params[:id])
        authorize! :destroy, @course
        if @course.destroy
          redirect_to supplementary_courses_path, notice: 'Course destroyed'
        else
          redirect_to supplementary_courses_path, alert: 'Course not destroyed'
        end
      end

      private

      def create_record
        # Convert ActionController::Parameters to hash for Dry::Validation
        # Dry::Validation cannot read from Parameters objects directly
        Training::Supplementary::CreateCourse.new(
          Training::Supplementary::Repository.new,
          Training::Supplementary::CreateCourseForm
        ).call(raw_inputs: course_params.to_unsafe_h)
      end

      def course_params
        params
          .require(:course)
          .permit(
            :name, :payment_type, :slug, :place, :start_date, :kind, :end_date, :application_date, :end_application_date, :price_kw, :baner, :email_remarks, :question,
            :price_non_kw, :remarks, :category, :price, :one_day, :active, :cash, :paid_email, :expired_hours, :reserve_list, :baner_type, :state, :send_manually,
            :open, :packages, :limit, :last_fee_paid, :organizator_id, project_ids: [], package_types_attributes: [:id, :name, :cost, :membership, :_destroy]
          )
      end
    end
  end
end
