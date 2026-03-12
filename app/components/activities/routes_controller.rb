module Activities
  class RoutesController < ApplicationController
    include EitherMatcher
    append_view_path 'app/components'

    def liga_tradowa
      authorize! :see_dziki, ::Db::Activities::MountainRoute

      year = Date.new(params.fetch(:year, Date.current.year).to_i, 1, 1)
      @sort = params.fetch(:sort, 'points')
      @sort_dir = params.fetch(:dir, 'desc')

      leaders = Db::User.includes(mountain_routes: :photos).where.not(mountain_routes: { kurtyka_difficulty: nil }).where(mountain_routes: { route_type: 'trad_climbing', climbing_date: year.beginning_of_year..year.end_of_year })

      @season_leaders = leaders.map do |user|
        presenter = TradLeague::UserSeasonScoresPresenter.new(user: user, year: year.year.to_s)
        last_route = user.mountain_routes.select { |r| r.route_type == 'trad_climbing' && r.kurtyka_difficulty.present? }.max_by(&:climbing_date)
        { user: user, points: presenter.points, routes: presenter.routes_count, likes: presenter.hearts_count, last_route: last_route }
      end

      @season_leaders = case @sort
        when 'routes' then @season_leaders.sort_by { |r| r[:routes] }
        when 'likes'  then @season_leaders.sort_by { |r| r[:likes] }
        else               @season_leaders.sort_by { |r| r[:points] }
      end

      @season_leaders = @season_leaders.reverse if @sort_dir == 'desc'
    end

    def gorskie_dziki
      authorize! :see_dziki, ::Db::Activities::MountainRoute

      @prev_month_leaders = climbing_repository.fetch_prev_month
      @current_month_leaders = climbing_repository.fetch_current_month
      @season_leaders = climbing_repository.fetch_season
      @best_of_season = climbing_repository.best_of_season
      @best_route_of_season = climbing_repository.best_route_of_season
      @tatra_uniqe = climbing_repository.tatra_uniqe
    end

    def gorskie_dziki_regulamin; end

    def narciarskie_dziki_month
      authorize! :see_dziki, ::Db::Activities::MountainRoute

      @specific_month_leaders = ski_repository.fetch_specific_month_with_gender([nil, :male, :female], params[:year].to_i, params[:month].to_i)
      @specific_month_leaders_male = ski_repository.fetch_specific_month_with_gender([nil, :male], params[:year].to_i, params[:month].to_i)
      @specific_month_leaders_female = ski_repository.fetch_specific_month_with_gender(:female, params[:year].to_i, params[:month].to_i)
    end

    def unhide
      route = ::Db::Activities::MountainRoute.find(params[:id])
      route.update(hidden: false)

      redirect_to activities_mountain_routes_path, notice: 'Opublikowano'
    end

    def narciarskie_dziki
      authorize! :see_dziki, ::Db::Activities::MountainRoute

      @prev_prev_month_leaders = ski_repository.fetch_specific_month(2022, 12)
      @prev_month_leaders = ski_repository.fetch_prev_month
      @current_month_leaders = ski_repository.fetch_current_month
      @season_leaders = ski_repository.fetch_season
      @last_contracts = ski_repository.last_contracts.includes(:contract)
      @my_last_contracts = current_user.training_user_contracts.includes(:route, :contract)
      @best_of_season = ski_repository.best_of_season
      @best_route_of_season = ski_repository.best_route_of_season
    end

    def narciarskie_dziki_regulamin; end

    def index
      authorize! :read, ::Db::Activities::MountainRoute

      @mountain_routes = MountainRouteRecord.order(climbing_date: :desc).page(params[:page]).per(20)
    end

    private

    def climbing_repository
      @climbing_repository ||= ::Activities::ClimbingRepository.new
    end

    def ski_repository
      @ski_repository ||= SkiRepository.new
    end
  end
end
