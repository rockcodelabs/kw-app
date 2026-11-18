module TradLeague
  class UserSeasonScoresPresenter
    attr_reader :user, :year

    def initialize(user:, year: Date.today.year)
      @user = user
      @year = Date.new(year.to_i, 1, 1)
    end

    def call
      {
        points: points,
        routes_count: routes_count,
        hearts_count: hearts_count
      }
    end

    def points
      TradLeague::UserSeasonCalculator.new(user: user, year: year.year).call
    end

    def routes_count
      routes.count
    end

    def hearts_count
      routes.sum(:hearts_count)
    end

    private

    def period
      year.beginning_of_year..Date.new(year.year, 12, 15)
    end

    def routes
      Db::Activities::MountainRoute.where(
        user_id: user.id,
        climbing_date: period,
        route_type: 'trad_climbing'
      ).where.not(kurtyka_difficulty: nil)
       .where("climb_style IS NULL OR climb_style != ?", Db::Activities::MountainRoute.climb_styles['Greenpoint'])
    end
  end
end
