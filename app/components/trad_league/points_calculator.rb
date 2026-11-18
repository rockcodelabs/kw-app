module TradLeague
  class PointsCalculator
    attr_reader :route

    def initialize(route:)
      @route = route
    end

    def call
      return 0 if route.kurtyka_difficulty.nil?
      return 0 if route.climb_style == 'Greenpoint'

      case route.climb_style
      when 'RP'
        hp_points[route.kurtyka_difficulty]
      when 'Flash'
        flash_points[route.kurtyka_difficulty]
      when 'OS'
        onsight_points[route.kurtyka_difficulty]
      else
        hp_points[route.kurtyka_difficulty]
      end
    end

    private

    def hp_points
      {
        'III' => 0,
        'IV' => 1,
        'IV+' => 2,
        'V' => 3,
        'V+' => 5,
        'VI' => 8,
        'VI+' => 13,
        'VI.1' => 21,
        'VI.1+' => 34,
        'VI.2' => 55,
        'VI.2+' => 89,
        'VI.3' => 144,
        'VI.3+' => 233,
        'VI.4' => 377,
        'VI.4+' => 610,
        'VI.5' => 987,
        'VI.5+' => 1597
      }
    end

    def flash_points
      {
        'III' => 1,
        'IV' => 2,
        'IV+' => 4,
        'V' => 6,
        'V+' => 10,
        'VI' => 16,
        'VI+' => 26,
        'VI.1' => 42,
        'VI.1+' => 68,
        'VI.2' => 110,
        'VI.2+' => 178,
        'VI.3' => 288,
        'VI.3+' => 466,
        'VI.4' => 754,
        'VI.4+' => 1220,
        'VI.5' => 1974,
        'VI.5+' => 3194
      }
    end

    def onsight_points
      {
        'III' => 2,
        'IV' => 3,
        'IV+' => 6,
        'V' => 9,
        'V+' => 15,
        'VI' => 24,
        'VI+' => 39,
        'VI.1' => 63,
        'VI.1+' => 102,
        'VI.2' => 165,
        'VI.2+' => 267,
        'VI.3' => 432,
        'VI.3+' => 699,
        'VI.4' => 1131,
        'VI.4+' => 1830,
        'VI.5' => 2961,
        'VI.5+' => 4791
      }
    end
  end
end
