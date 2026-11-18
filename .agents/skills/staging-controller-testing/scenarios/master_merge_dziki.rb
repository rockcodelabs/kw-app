# frozen_string_literal: true

# Scenario: pages brought in by merging master into develop (G29):
# Gorskie Dziki table + profile, Tradowe Dziki / Liga tradowa, top bar links.
# Creates throwaway users and routes in the harness transaction (rolled back).
StagingHarness.run('Activities::RoutesController (master merge)') do |h|
  r      = h.routes
  member = h.user('member', active: true)
  outsider = h.user('outsider')
  anon   = h.client
  as     = ->(label, user) { h.client(label, user) }
  year   = Date.current.year

  mk = lambda do |attrs|
    route = Db::Activities::MountainRoute.create!({ user: member, climbing_date: Date.current - 3, rating: 3,
                                            description: 'stg-check', peak: 'Stg Peak', area: 'Stg Area',
                                            mountains: 'Stg', length: 500, time: '2h', hidden: false,
                                            training: false }.merge(attrs))
    # user.mountain_routes goes through route_colleagues
    Db::Activities::RouteColleagues.create!(colleague: member, mountain_route: route)
  end
  mk.call(name: 'stg-check regular', route_type: :regular_climbing)
  mk.call(name: 'stg-check trad', route_type: :trad_climbing, climb_style: :OS,
          difficulty: 'V+', kurtyka_difficulty: :'V+')

  h.info('paths', "liga=#{r.liga_tradowa_path(year: year)} tradowe=#{r.tradowe_dziki_path} gorskie=#{r.gorskie_dziki_path} profile=#{r.gorskie_dziki_profile_path(kw_id: member.kw_id)}")

  h.check('liga-tradowa/2026 routes', Rails.application.routes.recognize_path('/liga-tradowa/2026')[:action], 'liga_tradowa')
  h.check('liga-tradowa (no year) routes', Rails.application.routes.recognize_path('/liga-tradowa')[:action], 'liga_tradowa')
  h.check('tradowe-dziki routes', Rails.application.routes.recognize_path('/tradowe-dziki')[:action], 'liga_tradowa')
  h.check('gorskie-dziki/2025 routes', Rails.application.routes.recognize_path('/gorskie-dziki/2025')[:action], 'gorskie_dziki')

  pages = {
    'liga-tradowa/2026' => '/liga-tradowa/2026',
    "liga-tradowa/#{year}" => "/liga-tradowa/#{year}",
    'liga-tradowa (no year)' => '/liga-tradowa',
    'tradowe-dziki' => '/tradowe-dziki',
    'gorskie-dziki' => '/gorskie-dziki',
    "gorskie-dziki/#{year}" => "/gorskie-dziki/#{year}",
    'gorskie-dziki/2025' => '/gorskie-dziki/2025',
    'gorskie-dziki regulamin' => '/gorskie-dziki/regulamin',
    'gorskie-dziki profile' => "/gorskie-dziki/dzik/#{member.kw_id}",
    'narciarskie-dziki' => '/narciarskie-dziki'
  }

  pages.each do |name, path|
    h.check_denied("anonymous cannot open #{name}", h.client("anon-#{name}").get(path)) unless name.include?('regulamin')
    h.check_status("member opens #{name}", as.('member', member).get(path), 200)
  end
  h.check_denied('non-active user cannot open gorskie-dziki', as.('outsider', outsider).get('/gorskie-dziki'))
  h.check_denied('non-active user cannot open liga-tradowa', as.('outsider', outsider).get('/liga-tradowa/2026'))
  h.check_status('unknown kw_id profile redirects with flash (RecordNotFound handler)', as.('member', member).get('/gorskie-dziki/dzik/99999999'), 302)

  body = as.('member', member).get('/liga-tradowa/2026').body.to_s
  h.check('liga page renders the trad route owner', body.include?('Stg'), true)
  h.check('top bar links to Tradowe Dziki', body.include?('/liga-tradowa/2026'), true)
  h.check('top bar links to Gorskie Dziki', body.include?('/gorskie-dziki'), true)
  prof = as.('member', member).get("/gorskie-dziki/dzik/#{member.kw_id}").body.to_s
  h.check('profile shows the member name', prof.include?('Stg'), true)
end
