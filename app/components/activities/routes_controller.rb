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
        season_routes = user.mountain_routes.select { |r| r.route_type == 'trad_climbing' && r.kurtyka_difficulty.present? && r.climbing_date >= year.beginning_of_year && r.climbing_date <= year.end_of_year }.sort_by(&:climbing_date).reverse
        last_route = season_routes.first
        season_photos = season_routes.flat_map { |r| r.photos.select { |p| p.file.present? && p.file.thumb.present? } }.first(5)
        { user: user, points: presenter.points, routes: presenter.routes_count, likes: presenter.hearts_count, last_route: last_route, season_routes: season_routes, season_photos: season_photos }
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

      @year = params.fetch(:year, Date.current.year).to_i
      @repository = ::Activities::ClimbingRepository.new(year: @year)

      @first_year = @repository.first_year
      @last_year = @repository.last_year
      @available_years = @repository.available_years
      @visible_months = @repository.visible_months

      @month = params[:month].present? ? params[:month].to_i : default_month
      @month = nil unless @month && @repository.season_months.include?(@month)

      @sort = %w[meters routes hearts].include?(params[:sort]) ? params[:sort] : 'meters'
      @gender = %w[male female].include?(params[:gender]) ? params[:gender] : nil

      season_rows = @repository.season_rows
      month_rows  = @month ? @repository.month_rows(@month) : []

      @season_leaders = arrange(season_rows)
      @month_leaders  = arrange(month_rows)

      @records = build_records(season_rows)
      @gallery = build_gallery(season_rows)
      @area_stats = build_area_stats(season_rows)
      @teams = @repository.season_teams.first(10)
      @hall_of_fame = @repository.hall_of_fame

      @best_of_season = @repository.best_of_season
      @best_route_of_season = @repository.best_route_of_season
      @tatra_uniqe = @repository.tatra_uniqe
    end

    def gorskie_dziki_profile
      authorize! :see_dziki, ::Db::Activities::MountainRoute

      @user = Db::User.find_by!(kw_id: params[:kw_id])
      @year = params.fetch(:year, Date.current.year).to_i
      @profile = ::Activities::BoarProfile.new(user: @user, year: @year)
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

    def default_month
      if @year == Date.current.year
        Date.current.month if @repository.season_months.include?(Date.current.month)
      else
        @repository.season_months.last
      end
    end

    def arrange(rows)
      rows = rows.select { |row| row[:user].gender == @gender } if @gender
      sort_rows(rows, @sort)
    end

    def sort_rows(rows, sort)
      case sort
      when 'routes' then rows.sort_by { |row| [-row[:routes_count], -row[:meters]] }
      when 'hearts' then rows.sort_by { |row| [-row[:hearts], -row[:meters]] }
      else               rows.sort_by { |row| [-row[:meters], -row[:routes_count]] }
      end
    end

    def build_records(rows)
      routes = rows.flat_map { |row| row[:routes] }
      return nil if routes.empty?

      best_day = rows.flat_map do |row|
        row[:routes].group_by(&:climbing_date).map do |date, day_routes|
          { user: row[:user], date: date, meters: day_routes.sum { |r| r.length.to_i }, count: day_routes.size }
        end
      end.max_by { |day| day[:meters] }

      {
        longest: routes.max_by { |route| route.length.to_i },
        most_liked: routes.max_by { |route| route.hearts_count.to_i },
        best_day: best_day
      }
    end

    def build_area_stats(rows)
      rows
        .flat_map { |row| row[:routes] }
        .reject { |route| route.area.blank? }
        .group_by { |route| route.area.strip }
        .map { |area, area_routes| { area: area, count: area_routes.size, meters: area_routes.sum { |r| r.length.to_i } } }
        .sort_by { |stat| -stat[:meters] }
        .first(8)
    end

    def build_gallery(rows)
      rows
        .flat_map { |row| row[:routes].map { |route| [row[:user], route] } }
        .flat_map do |user, route|
          route.photos
            .select { |photo| photo.file.present? && photo.file.thumb.present? }
            .map { |photo| { user: user, route: route, photo: photo, hearts: route.hearts_count.to_i } }
        end
        .uniq { |item| item[:photo].id }
        .sort_by { |item| [-item[:hearts], -item[:route].length.to_i] }
        .first(30)
    end

    def ski_repository
      @ski_repository ||= SkiRepository.new
    end
  end
end
