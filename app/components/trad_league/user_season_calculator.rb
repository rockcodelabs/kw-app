module TradLeague
  class UserSeasonCalculator
    attr_reader :user, :year

    def initialize(user:, year: Date.today.year)
      @user = user
      @year = Date.new(year.to_i, 1, 1)
    end

    def call
      routes.inject(0) do |sum, route|
        sum + TradLeague::PointsCalculator.new(route: route).call
      end
    end

    private

    def period
      year.beginning_of_year..Date.new(year.year, 12, 15)
    end

    def routes
      Db::Activities::MountainRoute.where(user_id: user.id, climbing_date: period, route_type: 'trad_climbing')
        .where.not(kurtyka_difficulty: nil)
        .where("climb_style IS NULL OR climb_style != ?", Db::Activities::MountainRoute.climb_styles['Greenpoint'])
    end
  end
end
