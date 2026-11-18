module Business
  module Api
    class CoursesController < ApplicationController
      def index
        courses = Business::CourseRecord.where(state: 'ready').where("starts_at >= ?", Date.today)
        courses = courses.order(starts_at: :asc)
        courses = courses.limit(params[:limit]) if params[:limit]

        render json: courses.to_json
      end
    end
  end
end
