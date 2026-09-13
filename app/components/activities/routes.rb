Rails.application.routes.draw do
  scope module: 'activities' do
    resources :routes, only: [] do
      member do
        put :unhide
      end
    end
    resources :competitions
    namespace :api do
      resources :routes, only: [:index] do
        member do
          get :season
          get :winter
          get :spring
        end
      end
      resources :competitions do
        collection do
          get :skimo
        end
      end
    end
  end

  get 'przejscia/tradowe' => 'activities/mountain_routes#new', as: :new_trad_route, defaults: { route_type: 'trad_climbing' }
  get "routes" => 'activities/routes#index'
  get "gorskie-dziki/regulamin" => 'activities/routes#gorskie_dziki_regulamin', as: :gorskie_dziki_regulamin
  get "gorskie-dziki/dzik/:kw_id" => 'activities/routes#gorskie_dziki_profile', as: :gorskie_dziki_profile
  get "gorskie-dziki(/:year)" => 'activities/routes#gorskie_dziki', as: :gorskie_dziki, constraints: { year: /\d{4}/ }
  get "tradowe-dziki", to: "activities/routes#liga_tradowa", as: :tradowe_dziki, defaults: { year: '2025' }
  get "narciarskie-dziki" => 'activities/routes#narciarskie_dziki', as: :narciarskie_dziki
  get "liga-tradowa/:year" => 'activities/routes#liga_tradowa', as: :liga_tradowa
  get "narciarskie-dziki/:year/:month" => 'activities/routes#narciarskie_dziki_month', as: :narciarskie_dziki_month
end
