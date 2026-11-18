module Activities
  # Statystyki pojedynczego dzika (uzytkownika) dla profilu:
  # dorobek sezonu, rozklad po miesiacach, rejony, trudnosci, odznaki,
  # oraz historia metrow rok po roku.
  class BoarProfile
    def initialize(user:, year: Date.current.year)
      @user = user
      @year = year.to_i
    end

    attr_reader :user, :year

    def routes
      @routes ||= qualifying_routes(season_range).sort_by(&:climbing_date).reverse
    end

    def total_meters
      @total_meters ||= routes.sum { |route| route.length.to_i }
    end

    def routes_count
      routes.size
    end

    def total_hearts
      @total_hearts ||= routes.sum { |route| route.hearts_count.to_i }
    end

    def meters_per_month
      ClimbingRepository::SEASON_START_MONTH.upto(ClimbingRepository::SEASON_END_MONTH).map do |month|
        meters = routes.select { |route| route.climbing_date.month == month }.sum { |route| route.length.to_i }
        { month: month, meters: meters }
      end
    end

    def areas
      routes
        .reject { |route| route.area.blank? }
        .group_by { |route| route.area.strip }
        .map { |area, rs| { area: area, count: rs.size, meters: rs.sum { |r| r.length.to_i } } }
        .sort_by { |row| -row[:meters] }
    end

    def difficulties
      routes
        .reject { |route| route.difficulty.blank? }
        .group_by { |route| route.difficulty.strip }
        .map { |difficulty, rs| { difficulty: difficulty, count: rs.size } }
        .sort_by { |row| -row[:count] }
    end

    def badges
      ::Activities::BoarBadges.new(
        meters: total_meters,
        routes_count: routes_count,
        hearts: total_hearts,
        routes: routes
      ).list
    end

    # [{ year:, meters: }] dla wszystkich sezonow – do wykresu historii.
    def history
      (ClimbingRepository::FIRST_SEASON_YEAR..Date.current.year).map do |season_year|
        meters = user
          .mountain_routes
          .where(route_type: 'regular_climbing')
          .where.not(length: nil, difficulty: ClimbingRepository::EXCLUDED_DIFFICULTY)
          .where(climbing_date: season_range_for(season_year))
          .sum(:length)
          .to_i
        { year: season_year, meters: meters }
      end
    end

    private

    def qualifying_routes(range)
      user
        .mountain_routes
        .includes(:photos)
        .where(route_type: 'regular_climbing')
        .where.not(length: nil, difficulty: ClimbingRepository::EXCLUDED_DIFFICULTY)
        .where(climbing_date: range)
        .to_a
    end

    def season_range
      season_range_for(@year)
    end

    def season_range_for(season_year)
      DateTime.new(season_year, ClimbingRepository::SEASON_START_MONTH, 1).beginning_of_day..
        DateTime.new(season_year, ClimbingRepository::SEASON_END_MONTH, 30).end_of_day
    end
  end
end
