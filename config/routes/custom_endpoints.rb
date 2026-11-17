namespace :business do
  resources :course_types, only: [:index]
  resources :conversations, only: [:create] do
    resources :messages, only: [:create]
  end
  resources :payments, only: [] do
    member do
      post :charge
    end
  end
  resources :sign_ups do
    member do
      resources :lists, only: [:new, :create] do
        collection do
          post :ask
        end
      end
      post :send_second
    end
  end
  resources :lists, only: [:index]
end

scope module: 'business' do
  resources :courses do
    collection do
      get :history
    end
    member do
      get :public
      put :seats_minus
      put :seats_plus
    end
  end

  namespace :api do
    resources :courses, only: :index
  end

  get 'zapotrzebowanie/:id' => 'lists#new', as: 'business_list'
  get 'kursy/:id' => 'courses#public', as: 'business_course_record_public'
  get 'courses/:id' => 'courses#show', as: 'business_course_record'
end

namespace :olx do
  resources :sale_announcements, path: "ogloszenia"
end

scope module: 'blog' do
  namespace :api do
    resources :authors
    resources :dashboard
  end
end

get "zawody/*name" => 'events/competitions/sign_ups#index', as: :zawody

scope module: 'events' do
  resources :competitions, only: [] do
    resources :sign_ups, controller: 'competitions/sign_ups' do
      member do
        put :send_email
      end
    end
  end

  namespace :admin do
    resources :competitions do
      member do
        put :toggle_closed
      end
    end
  end
end

scope module: 'library' do
  namespace :admin do
    resources :tags
  end
end

get 'biblioteka/wypozyczenia', to: 'library/item_reservations#index', as: :biblioteka_wypozyczenia, params: { q: { back_at_null: true, returned_at_lteq: Date.tomorrow } }
namespace :library do
  resources :items
  resources :authors
  resources :item_reservations do
    member do
      put :return
      put :remind
    end
  end
end

get 'biblioteka', to: 'library/items#index', as: :biblioteka
get 'tagi', to: 'library/admin/tags#index', as: :tagi
get 'biblioteka/:id', to: 'library/items#show', as: :ksiazka
get 'biblioteka/autorzy/:id', to: 'library/authors#show', as: :autor

scope module: 'storage' do
  resources :uploads
  namespace :api do
    resources :uploads
  end
end



scope module: 'training' do
  namespace :activities do
    resources :strava, only: [:index, :create, :new] do
      collection do
        get :callback
      end
    end
    namespace :api do
      resources :mountain_route_points
      resources :strava_activities, only: [:index, :create] do
        collection do
          get '/callback' => 'strava_activities#subscribe'
          post '/callback' => 'strava_activities#callback'
        end
      end
      resources :mountain_routes, only: :index
      resources :boars, only: :index
    end
    resources :ski_routes
    resources :contracts
    resources :user_contracts, only: [:create, :destroy]

    match 'heart', to: 'hearts#heart', via: :post
    match 'unheart', to: 'hearts#unheart', via: :delete
  end

  namespace :questionare do
    resources :snw_profiles, only: [:new, :create]
  end

  get 'wydarzenia/:id' => 'supplementary/courses#show', as: 'training_supplementary_course_record'

  namespace :supplementary do
    namespace :api do
      resources :courses, only: :index
    end
    resources :courses do
      resources :packages, only: [:new, :create]
      collection do
        get :archived
      end
    end
    resources :sign_ups do
      member do
        put :send_email
        put :cancel_cash_payment
      end
      collection do
        get :cancel
        put :manually
      end
    end
  end
end

get 'narciarskie-dziki/kontrakty' => 'training/activities/contracts#index', as: :kontrakty
get 'przejscia/narciarstwo' => 'training/activities/ski_routes#new', as: :narciarstwo
get 'przejscia/wspinaczka' => 'activities/mountain_routes#new', as: :wspinaczka
get 'wydarzenia/narciarskie' => 'training/supplementary/courses#index', defaults: { category: 'snw' }, as: :ski_events
get 'wydarzenia/wspinaczkowe' => 'training/supplementary/courses#index', defaults: { category: 'sww' }, as: :climbing_events
get 'wydarzenia/webinary' => 'training/supplementary/courses#index', defaults: { category: 'web' }, as: :web_events
get 'wydarzenia' => 'training/supplementary/courses#index', as: :wydarzenia
get 'wydarzenia/*id' => 'training/supplementary/courses#show', as: :polish_event
get 'wydarzenia/*slug' => 'training/supplementary/courses#show', as: :polish_event_slug
get 'wydarzenie/wypisz/*code' => 'training/supplementary/sign_ups#cancel', as: :polish_event_cancel

scope module: 'scrappers' do
  resources :scrappers, path: 'warunki', only: :index
  resources :graphs, only: :index
  namespace :api do
    resources :pogodynka, only: [:index]
    resources :meteoblue, only: [:index]
  end
end

scope module: 'marketing' do
  resources :sponsorship_requests
  resources :discounts, path: 'rabaty'
end

scope module: 'messaging' do
  namespace :api do
    resources :comments, only: :index
  end
  resources :comments
  resources :conversations do
    post :add_participant, on: :member
    put :opt_out, on: :member
    put :opt_in, on: :member

    resources :messages
  end
end

get 'wiadomosci' => 'messaging/conversations#index'

scope module: 'settlement' do
  namespace :api do
    resources :contractors
  end
  namespace :admin do
    resources :contractors
    resources :project_items, only: [:create, :update]
    resources :incomes, only: :create
    resources :projects do
      member do
        put :close
      end
    end
    resources :contracts do
      collection do
        get :history
        get :archive
      end
      member do
        get :download_attachment
        put :accept
        put :prepayment
        put :finish
      end
    end
  end
end

get "rozlicz" => 'settlement/admin/contracts#new'
get "rozliczenia" => 'settlement/admin/contracts#index'
get "rozliczenia/analiza/:year" => 'settlement/admin/contracts#analiza'


scope module: 'management' do
  namespace :api do
    resources :projects, only: :index
  end
  resources :projects, path: 'projekty'
  resources :resolutions, path: 'uchwaly'
  resources :settings, path: 'ustawienia', only: [:index, :edit, :update]
  scope module: 'voting' do
    get 'glosowania/pelnomocnictwo' => 'commissions#new'
    resources :commissions, only: [:new, :create]
    resources :case_presences, only: [:create, :destroy]
    resources :cases, path: 'glosowania' do
      collection do
        get :walne, as: :walne
        get :obecni, as: :obecni
        post :accept, as: :accept
      end
      member do
        resources :votes
        get :approve
        get :abstain
        put :approve_for_all
        put :hide
        get :unapprove
      end
    end
  end
  scope module: 'news' do
    namespace :api do
      resources :informations, only: :index
    end
    resources :informations, path: 'informacje'
  end
end

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
get "gorskie-dziki" => 'activities/routes#gorskie_dziki', as: :gorskie_dziki
get "tradowe-dziki" => 'activities/routes#liga_tradowa', as: :tradowe_dziki
get "narciarskie-dziki" => 'activities/routes#narciarskie_dziki', as: :narciarskie_dziki
get "liga-tradowa" => 'activities/routes#liga_tradowa', as: :liga_tradowa
get "narciarskie-dziki/:year/:month" => 'activities/routes#narciarskie_dziki_month', as: :narciarskie_dziki_month

scope module: 'yearly_prize' do
  namespace :admin do
    resources :yearly_prize_editions, only: [:index, :new, :create, :show, :edit, :update]
  end
end

get "/osemka/:year" => "yearly_prize/editions/requests#index", as: :yearly_prize_edition_requests
get "/osemka/:year/zgloszenie" => "yearly_prize/editions/requests#new", as: :yearly_prize
post "/osemka/:year/zgloszenie" => "yearly_prize/editions/requests#create", as: :yearly_prize_requests
get "/osemka/:year/zgloszenie/:request_id" => "yearly_prize/editions/requests#show", as: :yearly_prize_request
get "/osemka/:year/zgloszenie/:request_id/edit" => "yearly_prize/editions/requests#edit", as: :edit_yearly_prize_request
patch "/osemka/:year/zgloszenie/:request_id" => "yearly_prize/editions/requests#update"
put "/osemka/:year/zgloszenie/:request_id" => "yearly_prize/editions/requests#update"

mount_griddler

scope module: 'email_center' do
  namespace :admin do
    resources :email_records, only: [:destroy]
  end
  namespace :api do
    resources :emails, only: [] do
      collection do
        post :delivered
      end
    end
  end
end

get "prezentacje/zglos" => 'club_meetings/ideas#new'

scope module: 'club_meetings' do
  resources :ideas
end

scope module: 'management' do
  scope module: 'snw' do
    namespace :api do
      resources :snw_applies
    end
    resources :snw_applies
  end
end

get 'snw/zgloszenie' => 'management/snw/snw_applies#new'
get 'snw/zgloszenie/:id' => 'management/snw/snw_applies#show', as: :snw_apply_page

scope module: 'user_management' do
  resources :profiles, only: [] do
    resources :lists do
      member do
        post :accept
      end
    end
  end
end

namespace :membership do
  namespace :admin do
    resources :membership_fees, only: [] do
      collection do
        get :unpaid
        post :check_emails
      end
    end
  end
end

scope module: 'photo_competition' do
  resources :editions, only: [:show] do
    resources :requests do
      put :accept, on: :member
    end
  end

  namespace :admin do
    resources :editions do
      resources :categories, only: [:new, :create, :edit, :update], controller: 'editions/categories'
    end
  end
end

get "konkurs/:edition_id" => 'photo_competition/requests#new'
get "konkurs/:edition_code/glosowanie" => 'photo_competition/editions#show'

scope module: 'training' do
  scope module: 'bluebook' do
    resources :exercises
  end
end

scope module: 'notification_center' do
  resources :notifications, only: [:index] do
    collection do
      post :mark_as_read
    end
  end
end
