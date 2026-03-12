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
    @route_sort = params[:route_sort].presence || 'climbing_date'
    @route_dir  = params[:route_dir].presence  || 'desc'

    all_routes = repository.fetch_mountain_routes(@user)
    all_routes = all_routes.select { |r| r.route_type == @route_type_filter } if @route_type_filter

    all_routes = case @route_sort
    when 'difficulty'
      all_routes.sort_by { |r| (r.trad_climbing? || r.sport_climbing? ? r.kurtyka_difficulty.to_s : r.difficulty.to_s) }
    when 'hearts_count'
      all_routes.sort_by { |r| r.hearts_count.to_i }
    else
      all_routes.sort_by { |r| r.climbing_date || Date.new(1900) }
    end

    all_routes.reverse! if @route_dir == 'desc'

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
