module Activities
  class ClimbingRepository
    SEASON_START_MONTH = 6
    SEASON_END_MONTH = 11
    FIRST_SEASON_YEAR = 2016

    def initialize(year: Date.current.year)
      @year = year.to_i
    end

    attr_reader :year

    def first_year
      FIRST_SEASON_YEAR
    end

    def last_year
      Date.current.year
    end

    def season_months
      (SEASON_START_MONTH..SEASON_END_MONTH).to_a
    end

    # Miesiace sezonu, ktore maja sens do pokazania dla wybranego roku
    # (dla biezacego roku nie pokazujemy miesiecy z przyszlosci).
    def visible_months
      return season_months if @year < Date.current.year

      season_months.select { |month| month <= Date.current.month }
    end

    # Klasyfikacja calego sezonu (czerwiec–listopad danego roku).
    def season_rows
      rows_for(start_date.to_date, end_date.to_date, end_date.to_date + 5.days)
    end

    # Klasyfikacja pojedynczego miesiaca.
    def month_rows(month)
      first_day = Date.new(@year, month, 1)
      last_day  = first_day.end_of_month
      rows_for(first_day, last_day, last_day + 5.days)
    end

    def best_route_of_season
      ::Db::Activities::MountainRoute
        .where.not(id: nil, length: nil, difficulty: excluded_difficulty)
        .where(route_type: route_type, climbing_date: range, created_at: range)
        .select('id, name, slug, MAX(hearts_count) AS max_mountain_routes_hearts_count')
        .group(:id)
        .order('max_mountain_routes_hearts_count DESC')
    end

    def best_of_season
      ::Db::User
        .joins(:mountain_routes)
        .where.not(mountain_routes: { id: nil, length: nil, difficulty: excluded_difficulty })
        .where(climbing_boars: true, mountain_routes: { route_type: route_type, climbing_date: range, created_at: range })
        .select('users.kw_id, users.id, users.avatar, SUM(mountain_routes.hearts_count) AS total_mountain_routes_hearts_count')
        .group(:id)
        .order('total_mountain_routes_hearts_count DESC')
    end

    def tatra_uniqe
      ::Db::User
        .joins(:mountain_routes)
        .where.not(mountain_routes: { id: nil, length: nil, difficulty: excluded_difficulty })
        .where(climbing_boars: true, mountain_routes: { route_type: route_type, climbing_date: range, created_at: range })
        .where("mountain_routes.description LIKE ?", "%#exploratortatr%").uniq
        .sort_by { |u| u.mountain_routes.where("description LIKE '%#exploratortatr%'").count }.reverse!
    end

    def start_date
      DateTime.new(@year, SEASON_START_MONTH, 1).beginning_of_day
    end

    def end_date
      DateTime.new(@year, SEASON_END_MONTH, 30).end_of_day
    end

    private

    def rows_for(first_date, last_date, created_last_date)
      climbing_range = first_date.beginning_of_day..last_date.end_of_day
      created_range  = first_date.beginning_of_day..created_last_date.end_of_day

      users = ::Db::User
        .where(climbing_boars: true)
        .includes(mountain_routes: :photos)
        .where.not(mountain_routes: { id: nil, length: nil, difficulty: excluded_difficulty })
        .where(mountain_routes: { route_type: route_type, climbing_date: climbing_range, created_at: created_range })

      users.map do |user|
        routes = user.mountain_routes.select do |route|
          route.route_type == 'regular_climbing' &&
            route.length.present? &&
            excluded_difficulty.exclude?(route.difficulty) &&
            route.climbing_date.present? &&
            route.climbing_date >= first_date && route.climbing_date <= last_date
        end.sort_by(&:climbing_date).reverse

        next if routes.empty?

        photos = routes
          .flat_map { |route| route.photos.select { |photo| photo.file.present? && photo.file.thumb.present? } }
          .first(5)

        {
          user: user,
          meters: routes.sum { |route| route.length.to_i },
          routes_count: routes.size,
          hearts: routes.sum { |route| route.hearts_count.to_i },
          last_route: routes.first,
          routes: routes,
          photos: photos
        }
      end.compact.sort_by { |row| -row[:meters] }
    end

    def route_type
      'regular_climbing'
    end

    def range
      start_date..end_date
    end

    def excluded_difficulty
      [nil, '0', '0+', '0 +', '2', '2+', '2 +', '3', '3+', '3 +', 'I', 'II', 'II+', 'II +', 'III', 'III+', 'III +', '+III']
    end
  end
end
