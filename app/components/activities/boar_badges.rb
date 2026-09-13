module Activities
  # Wylicza odznaki (achievementy) dla dzika na podstawie jego dorobku
  # w danym zakresie (miesiac / sezon).
  class BoarBadges
    def initialize(meters:, routes_count:, hearts:, routes:)
      @meters = meters.to_i
      @routes_count = routes_count.to_i
      @hearts = hearts.to_i
      @routes = routes || []
    end

    # Zwraca liste hashy: { icon:, label:, title: }
    def list
      badges = []

      if @meters >= 2000
        badges << badge('🥇', "#{@meters} m", 'Ponad 2000 metrów!')
      elsif @meters >= 1000
        badges << badge('🏔️', "#{@meters} m", 'Ponad 1000 metrów')
      elsif @meters >= 500
        badges << badge('⛰️', "#{@meters} m", 'Ponad 500 metrów')
      end

      badges << badge('🔟', "#{@routes_count} dróg", 'Co najmniej 10 dróg') if @routes_count >= 10
      badges << badge('❤️', 'Ulubieniec', "#{@hearts} bicków") if @hearts >= 50
      badges << badge('🧭', 'Odkrywca', '#exploratortatr') if tag?('#exploratortatr')
      badges << badge('👴', 'Dziadek Gienek', '#dziadekgienek') if tag?('#dziadekgienek')
      badges << badge('💪', 'Mocarz VI', 'Przejście VI lub trudniejsze') if hard_route?

      badges
    end

    private

    def badge(icon, label, title)
      { icon: icon, label: label, title: title }
    end

    def tag?(tag)
      @routes.any? { |route| route.description.to_s.downcase.include?(tag) }
    end

    def hard_route?
      @routes.any? { |route| route.difficulty.to_s.strip =~ /\AVI/ }
    end
  end
end
