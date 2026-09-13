module Activities
  class ClimbingRepository
    SEASON_START_MONTH = 6
    SEASON_END_MONTH = 11
    FIRST_SEASON_YEAR = 2016

    EXCLUDED_DIFFICULTY = [
      nil, '0', '0+', '0 +', '2', '2+', '2 +', '3', '3+', '3 +',
      'I', 'II', 'II+', 'II +', 'III', 'III+', 'III +', '+III'
    ].freeze

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

    # Lata sezonu, ktore maja przynajmniej jedno zaliczane przejscie
    # (do nawigacji – nie pokazujemy pustych lat).
    def available_years
      years = ::Db::Activities::MountainRoute
        .where(route_type: route_type)
        .where.not(length: nil, difficulty: EXCLUDED_DIFFICULTY)
        .where('EXTRACT(MONTH FROM climbing_date) BETWEEN ? AND ?', SEASON_START_MONTH, SEASON_END_MONTH)
        .distinct
        .pluck(Arel.sql('EXTRACT(YEAR FROM climbing_date)::int'))
        .select { |y| y >= FIRST_SEASON_YEAR && y <= last_year }

      (years | [@year]).sort
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

    # Klasyfikacja par/zespolow dla calego sezonu.
    def season_teams
      teams_for(start_date.to_date, end_date.to_date, end_date.to_date + 5.days)
    end

    # Klasyfikacja par/zespolow dla pojedynczego miesiaca.
    def month_teams(month)
      first_day = Date.new(@year, month, 1)
      last_day  = first_day.end_of_month
      teams_for(first_day, last_day, last_day + 5.days)
    end

    # Hala slaw – mistrz sezonu (metry) dla kazdego roku, malejaco.
    def hall_of_fame
      (first_year..last_year).to_a.reverse.map do |season_year|
        champion = season_aggregate(season_year).first
        next if champion.nil?

        { year: season_year, user: champion, meters: champion.total_length.to_i }
      end.compact
    end

    def best_route_of_season
      ::Db::Activities::MountainRoute
        .where.not(id: nil, length: nil, difficulty: EXCLUDED_DIFFICULTY)
        .where(route_type: route_type, climbing_date: range, created_at: range)
        .select('id, name, slug, MAX(hearts_count) AS max_mountain_routes_hearts_count')
        .group(:id)
        .order('max_mountain_routes_hearts_count DESC')
    end

    def best_of_season
      ::Db::User
        .joins(:mountain_routes)
        .where.not(mountain_routes: { id: nil, length: nil, difficulty: EXCLUDED_DIFFICULTY })
        .where(climbing_boars: true, mountain_routes: { route_type: route_type, climbing_date: range, created_at: range })
        .select('users.kw_id, users.id, users.avatar, SUM(mountain_routes.hearts_count) AS total_mountain_routes_hearts_count')
        .group(:id)
        .order('total_mountain_routes_hearts_count DESC')
    end

    def tatra_uniqe
      ::Db::User
        .joins(:mountain_routes)
        .where.not(mountain_routes: { id: nil, length: nil, difficulty: EXCLUDED_DIFFICULTY })
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
        .where.not(mountain_routes: { id: nil, length: nil, difficulty: EXCLUDED_DIFFICULTY })
        .where(mountain_routes: { route_type: route_type, climbing_date: climbing_range, created_at: created_range })

      users.map do |user|
        routes = user.mountain_routes.select do |route|
          route.route_type == 'regular_climbing' &&
            route.length.present? &&
            EXCLUDED_DIFFICULTY.exclude?(route.difficulty) &&
            route.climbing_date.present? &&
            route.climbing_date >= first_date && route.climbing_date <= last_date
        end.sort_by(&:climbing_date).reverse

        next if routes.empty?

        photos = routes
          .flat_map { |route| route.photos.select { |photo| photo.file.present? && photo.file.thumb.present? } }
          .first(5)

        meters = routes.sum { |route| route.length.to_i }
        hearts = routes.sum { |route| route.hearts_count.to_i }

        {
          user: user,
          meters: meters,
          routes_count: routes.size,
          hearts: hearts,
          last_route: routes.first,
          routes: routes,
          photos: photos,
          badges: ::Activities::BoarBadges.new(meters: meters, routes_count: routes.size, hearts: hearts, routes: routes).list
        }
      end.compact.sort_by { |row| -row[:meters] }
    end

    def teams_for(first_date, last_date, created_last_date)
      climbing_range = first_date.beginning_of_day..last_date.end_of_day
      created_range  = first_date.beginning_of_day..created_last_date.end_of_day

      routes = ::Db::Activities::MountainRoute
        .includes(:colleagues)
        .where.not(length: nil, difficulty: EXCLUDED_DIFFICULTY)
        .where(route_type: route_type, climbing_date: climbing_range, created_at: created_range)

      pairs = {}
      routes.each do |route|
        partners = route.colleagues.select(&:climbing_boars).uniq
        partners.combination(2).each do |a, b|
          ordered = [a, b].sort_by(&:id)
          key = ordered.map(&:id)
          pairs[key] ||= { users: ordered, routes_count: 0, meters: 0 }
          pairs[key][:routes_count] += 1
          pairs[key][:meters] += route.length.to_i
        end
      end

      pairs.values.sort_by { |pair| [-pair[:routes_count], -pair[:meters]] }
    end

    # Lekki agregat (bez ladowania tras/zdjec) – uzywany w hali slaw.
    def season_aggregate(season_year)
      climbing_range = DateTime.new(season_year, SEASON_START_MONTH, 1).beginning_of_day..DateTime.new(season_year, SEASON_END_MONTH, 30).end_of_day
      created_range  = climbing_range.begin..(climbing_range.end + 5.days)

      ::Db::User
        .joins(:mountain_routes)
        .where(climbing_boars: true)
        .where.not(mountain_routes: { id: nil, length: nil, difficulty: EXCLUDED_DIFFICULTY })
        .where(mountain_routes: { route_type: route_type, climbing_date: climbing_range, created_at: created_range })
        .select('users.id, users.kw_id, users.avatar, users.first_name, users.last_name, SUM(mountain_routes.length) AS total_length')
        .group('users.id')
        .order('total_length DESC')
    end

    def route_type
      'regular_climbing'
    end

    def range
      start_date..end_date
    end
  end
end
