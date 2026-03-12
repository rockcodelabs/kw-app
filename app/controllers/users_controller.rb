class UsersController < ApplicationController
  append_view_path 'app/components'
  def index
    return redirect_to root_path, alert: 'Musisz być zalogowany i aktywny!' unless user_signed_in? && current_user.active?
    @q = Db::User.includes(:profile, :membership_fees).where.not(kw_id: nil).not_hidden.ransack(params[:q])
    @q.sorts = ['kw_id desc', 'created_at desc'] if @q.sorts.empty?
    @users = @q.result.page(params[:page])
  end

  def show
    return redirect_to root_path, alert: 'Musisz być zalogowany i aktywny!' unless user_signed_in? && current_user.active?
    return redirect_to root_path, alert: 'Użytkownik o podanym numerze nie posiada konta w systemie' unless Db::User.exists?(kw_id: params[:kw_id])

    @user = Db::User.find_by(kw_id: params[:kw_id])
    @route_type_filter = params[:route_type].presence
    all_routes = repository.fetch_mountain_routes(@user)
    all_routes = all_routes.select { |r| r.route_type == @route_type_filter } if @route_type_filter
    @my_routes = Kaminari.paginate_array(all_routes).page(params[:route_page]).per(5)
    @my_courses = Kaminari.paginate_array(repository.fetch_courses(@user)).page(params[:course_page]).per(5)
    @my_projects = Kaminari.paginate_array(repository.fetch_projects(@user)).page(params[:project_page]).per(5)
    @my_training_contracts = @user.training_user_contracts.page(params[:training_contract_page]).per(5)
  end

  private

  def repository
    Membership::Card::Repository.new
  end
end
