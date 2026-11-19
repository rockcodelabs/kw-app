module Blog
  class Dashboard
    def fetch
      {
        total_meters: routes.sum(:length),
        last_route: { name: routes.last.name, date: routes.last.climbing_date },
        max_meters_person: { name: Db::User.find_by(kw_id: best_person.kw_id).display_name, meters: best_person.total_mountain_routes_length }
      }.to_json
    end

    private

    def routes
      Db::Activities::MountainRoute.where(route_type: 'ski').order(:climbing_date)
    end

    def best_person
      Activities::SkiRepository.new.fetch_season.order('total_mountain_routes_length DESC').first
    end
  end
end
