# == Route Map
#
#                                        Prefix Verb     URI Pattern                                                                              Controller#Action
#                              new_user_session GET      /users/sign_in(.:format)                                                                 devise/sessions#new
#                                  user_session POST     /users/sign_in(.:format)                                                                 devise/sessions#create
#                          destroy_user_session GET      /users/sign_out(.:format)                                                                devise/sessions#destroy
#         user_google_oauth2_omniauth_authorize GET|POST /users/auth/google_oauth2(.:format)                                                      users/omniauth_callbacks#passthru
#          user_google_oauth2_omniauth_callback GET|POST /users/auth/google_oauth2/callback(.:format)                                             users/omniauth_callbacks#google_oauth2
#                             new_user_password GET      /users/password/new(.:format)                                                            devise/passwords#new
#                            edit_user_password GET      /users/password/edit(.:format)                                                           devise/passwords#edit
#                                 user_password PATCH    /users/password(.:format)                                                                devise/passwords#update
#                                               PUT      /users/password(.:format)                                                                devise/passwords#update
#                                               POST     /users/password(.:format)                                                                devise/passwords#create
#                      cancel_user_registration GET      /users/cancel(.:format)                                                                  registrations#cancel
#                         new_user_registration GET      /users/sign_up(.:format)                                                                 registrations#new
#                        edit_user_registration GET      /users/edit(.:format)                                                                    registrations#edit
#                             user_registration PATCH    /users(.:format)                                                                         registrations#update
#                                               PUT      /users(.:format)                                                                         registrations#update
#                                               DELETE   /users(.:format)                                                                         registrations#destroy
#                                               POST     /users(.:format)                                                                         registrations#create
#                                       zaloguj GET      /zaloguj(.:format)                                                                       devise/sessions#new
#                                   zarejestruj GET      /zarejestruj(.:format)                                                                   devise/registrations#new
#                                   sidekiq_web          /sidekiq                                                                                 Sidekiq::Web
#                                    wiadomosci GET      /wiadomosci(.:format)                                                                    messaging/conversations#index
#                       wypozyczalnia_regulamin GET      /wypozyczalnia/regulamin(.:format)                                                       pages#show {:id=>"rules"}
#                          biblioteka_regulamin GET      /biblioteka/regulamin(.:format)                                                          pages#show {:id=>"rules"}
#                   serwis_narciarski_regulamin GET      /serwis-narciarski/regulamin(.:format)                                                   pages#show {:id=>"rules"}
#                          wydarzenia_regulamin GET      /wydarzenia/regulamin(.:format)                                                          pages#show {:id=>"rules"}
#                       glosowania_dane_osobowe GET      /glosowania/dane-osobowe(.:format)                                                       pages#show {:id=>"rules"}
#                         glosowania_instrukcja GET      /glosowania/instrukcja(.:format)                                                         pages#show {:id=>"rules"}
#                   narciarskie_dziki_regulamin GET      /narciarskie-dziki/regulamin(.:format)                                                   pages#show {:id=>"rules"}
#                   konkurs_kasprzyka_regulamin GET      /konkurs_kasprzyka/regulamin(.:format)                                                   pages#show {:id=>"rules"}
#                         instrukcje_wydarzenia GET      /instrukcje/wydarzenia(.:format)                                                         pages#show {:id=>"rules"}
#                                      kontakty GET      /kontakty(.:format)                                                                      pages#show {:id=>"kontakty"}
#                           wydarzenia_webinary GET      /wydarzenia/webinary(.:format)                                                           redirect(301)
#                                     marketing GET      /marketing(.:format)                                                                     redirect(301)
#                                        zawody GET      /zawody/*name(.:format)                                                                  events/competitions/sign_ups#index
#                send_email_competition_sign_up PUT      /competitions/:competition_id/sign_ups/:id/send_email(.:format)                          events/competitions/sign_ups#send_email
#                          competition_sign_ups GET      /competitions/:competition_id/sign_ups(.:format)                                         events/competitions/sign_ups#index
#                                               POST     /competitions/:competition_id/sign_ups(.:format)                                         events/competitions/sign_ups#create
#                       new_competition_sign_up GET      /competitions/:competition_id/sign_ups/new(.:format)                                     events/competitions/sign_ups#new
#                      edit_competition_sign_up GET      /competitions/:competition_id/sign_ups/:id/edit(.:format)                                events/competitions/sign_ups#edit
#                           competition_sign_up GET      /competitions/:competition_id/sign_ups/:id(.:format)                                     events/competitions/sign_ups#show
#                                               PATCH    /competitions/:competition_id/sign_ups/:id(.:format)                                     events/competitions/sign_ups#update
#                                               PUT      /competitions/:competition_id/sign_ups/:id(.:format)                                     events/competitions/sign_ups#update
#                                               DELETE   /competitions/:competition_id/sign_ups/:id(.:format)                                     events/competitions/sign_ups#destroy
#               toggle_closed_admin_competition PUT      /admin/competitions/:id/toggle_closed(.:format)                                          events/admin/competitions#toggle_closed
#                            admin_competitions GET      /admin/competitions(.:format)                                                            events/admin/competitions#index
#                                               POST     /admin/competitions(.:format)                                                            events/admin/competitions#create
#                         new_admin_competition GET      /admin/competitions/new(.:format)                                                        events/admin/competitions#new
#                        edit_admin_competition GET      /admin/competitions/:id/edit(.:format)                                                   events/admin/competitions#edit
#                             admin_competition GET      /admin/competitions/:id(.:format)                                                        events/admin/competitions#show
#                                               PATCH    /admin/competitions/:id(.:format)                                                        events/admin/competitions#update
#                                               PUT      /admin/competitions/:id(.:format)                                                        events/admin/competitions#update
#                                               DELETE   /admin/competitions/:id(.:format)                                                        events/admin/competitions#destroy
#                        close_shop_admin_order PUT      /shop/admin/orders/:id/close(.:format)                                                   shop/admin/orders#close
#                             shop_admin_orders GET      /shop/admin/orders(.:format)                                                             shop/admin/orders#index
#                              shop_admin_order GET      /shop/admin/orders/:id(.:format)                                                         shop/admin/orders#show
#                              shop_admin_items GET      /shop/admin/items(.:format)                                                              shop/admin/items#index
#                               shop_admin_item GET      /shop/admin/items/:id(.:format)                                                          shop/admin/items#show
#                                               DELETE   /shop/admin/items/:id(.:format)                                                          shop/admin/items#destroy
#                                     api_items GET      /api/items(.:format)                                                                     shop/api/items#index
#                                               POST     /api/items(.:format)                                                                     shop/api/items#create
#                                  new_api_item GET      /api/items/new(.:format)                                                                 shop/api/items#new
#                                 edit_api_item GET      /api/items/:id/edit(.:format)                                                            shop/api/items#edit
#                                      api_item GET      /api/items/:id(.:format)                                                                 shop/api/items#show
#                                               PATCH    /api/items/:id(.:format)                                                                 shop/api/items#update
#                                               PUT      /api/items/:id(.:format)                                                                 shop/api/items#update
#                                               DELETE   /api/items/:id(.:format)                                                                 shop/api/items#destroy
#                                    api_orders POST     /api/orders(.:format)                                                                    shop/api/orders#create
#                                         items GET      /sklepik(.:format)                                                                       shop/items#index
#                                               POST     /sklepik(.:format)                                                                       shop/items#create
#                                      new_item GET      /sklepik/new(.:format)                                                                   shop/items#new
#                                     edit_item GET      /sklepik/:id/edit(.:format)                                                              shop/items#edit
#                                          item GET      /sklepik/:id(.:format)                                                                   shop/items#show
#                                               PATCH    /sklepik/:id(.:format)                                                                   shop/items#update
#                                               PUT      /sklepik/:id(.:format)                                                                   shop/items#update
#                                               DELETE   /sklepik/:id(.:format)                                                                   shop/items#destroy
#                                        orders GET      /zamowienia(.:format)                                                                    shop/orders#index
#                                               POST     /zamowienia(.:format)                                                                    shop/orders#create
#                                     new_order GET      /zamowienia/new(.:format)                                                                shop/orders#new
#                                    edit_order GET      /zamowienia/:id/edit(.:format)                                                           shop/orders#edit
#                                         order GET      /zamowienia/:id(.:format)                                                                shop/orders#show
#                                               PATCH    /zamowienia/:id(.:format)                                                                shop/orders#update
#                                               PUT      /zamowienia/:id(.:format)                                                                shop/orders#update
#                                               DELETE   /zamowienia/:id(.:format)                                                                shop/orders#destroy
#                                       sklepik GET      /sklepik(.:format)                                                                       shop/items#index
#                                 sklepik_admin GET      /sklepik-admin(.:format)                                                                 shop/items#admin
#                                               GET      /sklepik/:id(.:format)                                                                   shop/items#show
#                                       uploads GET      /uploads(.:format)                                                                       storage/uploads#index
#                                               POST     /uploads(.:format)                                                                       storage/uploads#create
#                                    new_upload GET      /uploads/new(.:format)                                                                   storage/uploads#new
#                                   edit_upload GET      /uploads/:id/edit(.:format)                                                              storage/uploads#edit
#                                        upload GET      /uploads/:id(.:format)                                                                   storage/uploads#show
#                                               PATCH    /uploads/:id(.:format)                                                                   storage/uploads#update
#                                               PUT      /uploads/:id(.:format)                                                                   storage/uploads#update
#                                               DELETE   /uploads/:id(.:format)                                                                   storage/uploads#destroy
#                                   api_uploads GET      /api/uploads(.:format)                                                                   storage/api/uploads#index
#                                               POST     /api/uploads(.:format)                                                                   storage/api/uploads#create
#                                new_api_upload GET      /api/uploads/new(.:format)                                                               storage/api/uploads#new
#                               edit_api_upload GET      /api/uploads/:id/edit(.:format)                                                          storage/api/uploads#edit
#                                    api_upload GET      /api/uploads/:id(.:format)                                                               storage/api/uploads#show
#                                               PATCH    /api/uploads/:id(.:format)                                                               storage/api/uploads#update
#                                               PUT      /api/uploads/:id(.:format)                                                               storage/api/uploads#update
#                                               DELETE   /api/uploads/:id(.:format)                                                               storage/api/uploads#destroy
#                          sponsorship_requests GET      /sponsorship_requests(.:format)                                                          marketing/sponsorship_requests#index
#                                               POST     /sponsorship_requests(.:format)                                                          marketing/sponsorship_requests#create
#                       new_sponsorship_request GET      /sponsorship_requests/new(.:format)                                                      marketing/sponsorship_requests#new
#                      edit_sponsorship_request GET      /sponsorship_requests/:id/edit(.:format)                                                 marketing/sponsorship_requests#edit
#                           sponsorship_request GET      /sponsorship_requests/:id(.:format)                                                      marketing/sponsorship_requests#show
#                                               PATCH    /sponsorship_requests/:id(.:format)                                                      marketing/sponsorship_requests#update
#                                               PUT      /sponsorship_requests/:id(.:format)                                                      marketing/sponsorship_requests#update
#                                               DELETE   /sponsorship_requests/:id(.:format)                                                      marketing/sponsorship_requests#destroy
#                                     discounts GET      /rabaty(.:format)                                                                        marketing/discounts#index
#                                               POST     /rabaty(.:format)                                                                        marketing/discounts#create
#                                  new_discount GET      /rabaty/new(.:format)                                                                    marketing/discounts#new
#                                 edit_discount GET      /rabaty/:id/edit(.:format)                                                               marketing/discounts#edit
#                                      discount GET      /rabaty/:id(.:format)                                                                    marketing/discounts#show
#                                               PATCH    /rabaty/:id(.:format)                                                                    marketing/discounts#update
#                                               PUT      /rabaty/:id(.:format)                                                                    marketing/discounts#update
#                                               DELETE   /rabaty/:id(.:format)                                                                    marketing/discounts#destroy
#                 yearly_prize_edition_requests GET      /osemka/:year(.:format)                                                                  yearly_prize/editions/requests#index
#                                  yearly_prize GET      /osemka/:year/zgloszenie(.:format)                                                       yearly_prize/editions/requests#new
#                         yearly_prize_requests POST     /osemka/:year/zgloszenie(.:format)                                                       yearly_prize/editions/requests#create
#                          yearly_prize_request GET      /osemka/:year/zgloszenie/:request_id(.:format)                                           yearly_prize/editions/requests#show
#                     edit_yearly_prize_request GET      /osemka/:year/zgloszenie/:request_id/edit(.:format)                                      yearly_prize/editions/requests#edit
#                                               PATCH    /osemka/:year/zgloszenie/:request_id(.:format)                                           yearly_prize/editions/requests#update
#                                               PUT      /osemka/:year/zgloszenie/:request_id(.:format)                                           yearly_prize/editions/requests#update
#                                     exercises GET      /exercises(.:format)                                                                     training/bluebook/exercises#index
#                                               POST     /exercises(.:format)                                                                     training/bluebook/exercises#create
#                                  new_exercise GET      /exercises/new(.:format)                                                                 training/bluebook/exercises#new
#                                 edit_exercise GET      /exercises/:id/edit(.:format)                                                            training/bluebook/exercises#edit
#                                      exercise GET      /exercises/:id(.:format)                                                                 training/bluebook/exercises#show
#                                               PATCH    /exercises/:id(.:format)                                                                 training/bluebook/exercises#update
#                                               PUT      /exercises/:id(.:format)                                                                 training/bluebook/exercises#update
#                                               DELETE   /exercises/:id(.:format)                                                                 training/bluebook/exercises#destroy
#                    mark_as_read_notifications POST     /notifications/mark_as_read(.:format)                                                    notification_center/notifications#mark_as_read
#                                 notifications GET      /notifications(.:format)                                                                 notification_center/notifications#index
#                               email_processor POST     /email_processor(.:format)                                                               griddler/emails#create
#                            admin_email_record DELETE   /admin/email_records/:id(.:format)                                                       email_center/admin/email_records#destroy
#                          delivered_api_emails POST     /api/emails/delivered(.:format)                                                          email_center/api/emails#delivered
#                                  unhide_route PUT      /routes/:id/unhide(.:format)                                                             activities/routes#unhide
#                                  competitions GET      /competitions(.:format)                                                                  activities/competitions#index
#                                               POST     /competitions(.:format)                                                                  activities/competitions#create
#                               new_competition GET      /competitions/new(.:format)                                                              activities/competitions#new
#                              edit_competition GET      /competitions/:id/edit(.:format)                                                         activities/competitions#edit
#                                   competition GET      /competitions/:id(.:format)                                                              activities/competitions#show
#                                               PATCH    /competitions/:id(.:format)                                                              activities/competitions#update
#                                               PUT      /competitions/:id(.:format)                                                              activities/competitions#update
#                                               DELETE   /competitions/:id(.:format)                                                              activities/competitions#destroy
#                              season_api_route GET      /api/routes/:id/season(.:format)                                                         activities/api/routes#season
#                              winter_api_route GET      /api/routes/:id/winter(.:format)                                                         activities/api/routes#winter
#                              spring_api_route GET      /api/routes/:id/spring(.:format)                                                         activities/api/routes#spring
#                                    api_routes GET      /api/routes(.:format)                                                                    activities/api/routes#index
#                        skimo_api_competitions GET      /api/competitions/skimo(.:format)                                                        activities/api/competitions#skimo
#                              api_competitions GET      /api/competitions(.:format)                                                              activities/api/competitions#index
#                                               POST     /api/competitions(.:format)                                                              activities/api/competitions#create
#                           new_api_competition GET      /api/competitions/new(.:format)                                                          activities/api/competitions#new
#                          edit_api_competition GET      /api/competitions/:id/edit(.:format)                                                     activities/api/competitions#edit
#                               api_competition GET      /api/competitions/:id(.:format)                                                          activities/api/competitions#show
#                                               PATCH    /api/competitions/:id(.:format)                                                          activities/api/competitions#update
#                                               PUT      /api/competitions/:id(.:format)                                                          activities/api/competitions#update
#                                               DELETE   /api/competitions/:id(.:format)                                                          activities/api/competitions#destroy
#                                        routes GET      /routes(.:format)                                                                        activities/routes#index
#                       gorskie_dziki_regulamin GET      /gorskie-dziki/regulamin(.:format)                                                       activities/routes#gorskie_dziki_regulamin
#                                 gorskie_dziki GET      /gorskie-dziki(.:format)                                                                 activities/routes#gorskie_dziki
#                             narciarskie_dziki GET      /narciarskie-dziki(.:format)                                                             activities/routes#narciarskie_dziki
#                       narciarskie_dziki_month GET      /narciarskie-dziki/:year/:month(.:format)                                                activities/routes#narciarskie_dziki_month
#                                  api_comments GET      /api/comments(.:format)                                                                  messaging/api/comments#index
#                                      comments GET      /comments(.:format)                                                                      messaging/comments#index
#                                               POST     /comments(.:format)                                                                      messaging/comments#create
#                                   new_comment GET      /comments/new(.:format)                                                                  messaging/comments#new
#                                  edit_comment GET      /comments/:id/edit(.:format)                                                             messaging/comments#edit
#                                       comment GET      /comments/:id(.:format)                                                                  messaging/comments#show
#                                               PATCH    /comments/:id(.:format)                                                                  messaging/comments#update
#                                               PUT      /comments/:id(.:format)                                                                  messaging/comments#update
#                                               DELETE   /comments/:id(.:format)                                                                  messaging/comments#destroy
#                  add_participant_conversation POST     /conversations/:id/add_participant(.:format)                                             messaging/conversations#add_participant
#                          opt_out_conversation PUT      /conversations/:id/opt_out(.:format)                                                     messaging/conversations#opt_out
#                           opt_in_conversation PUT      /conversations/:id/opt_in(.:format)                                                      messaging/conversations#opt_in
#                         conversation_messages GET      /conversations/:conversation_id/messages(.:format)                                       messaging/messages#index
#                                               POST     /conversations/:conversation_id/messages(.:format)                                       messaging/messages#create
#                      new_conversation_message GET      /conversations/:conversation_id/messages/new(.:format)                                   messaging/messages#new
#                     edit_conversation_message GET      /conversations/:conversation_id/messages/:id/edit(.:format)                              messaging/messages#edit
#                          conversation_message GET      /conversations/:conversation_id/messages/:id(.:format)                                   messaging/messages#show
#                                               PATCH    /conversations/:conversation_id/messages/:id(.:format)                                   messaging/messages#update
#                                               PUT      /conversations/:conversation_id/messages/:id(.:format)                                   messaging/messages#update
#                                               DELETE   /conversations/:conversation_id/messages/:id(.:format)                                   messaging/messages#destroy
#                                 conversations GET      /conversations(.:format)                                                                 messaging/conversations#index
#                                               POST     /conversations(.:format)                                                                 messaging/conversations#create
#                              new_conversation GET      /conversations/new(.:format)                                                             messaging/conversations#new
#                             edit_conversation GET      /conversations/:id/edit(.:format)                                                        messaging/conversations#edit
#                                  conversation GET      /conversations/:id(.:format)                                                             messaging/conversations#show
#                                               PATCH    /conversations/:id(.:format)                                                             messaging/conversations#update
#                                               PUT      /conversations/:id(.:format)                                                             messaging/conversations#update
#                                               DELETE   /conversations/:id(.:format)                                                             messaging/conversations#destroy
#                                               GET      /wiadomosci(.:format)                                                                    messaging/conversations#index
#                                  api_projects GET      /api/projects(.:format)                                                                  management/api/projects#index
#                                      projects GET      /projekty(.:format)                                                                      management/projects#index
#                                               POST     /projekty(.:format)                                                                      management/projects#create
#                                   new_project GET      /projekty/new(.:format)                                                                  management/projects#new
#                                  edit_project GET      /projekty/:id/edit(.:format)                                                             management/projects#edit
#                                       project GET      /projekty/:id(.:format)                                                                  management/projects#show
#                                               PATCH    /projekty/:id(.:format)                                                                  management/projects#update
#                                               PUT      /projekty/:id(.:format)                                                                  management/projects#update
#                                               DELETE   /projekty/:id(.:format)                                                                  management/projects#destroy
#                                   resolutions GET      /uchwaly(.:format)                                                                       management/resolutions#index
#                                               POST     /uchwaly(.:format)                                                                       management/resolutions#create
#                                new_resolution GET      /uchwaly/new(.:format)                                                                   management/resolutions#new
#                               edit_resolution GET      /uchwaly/:id/edit(.:format)                                                              management/resolutions#edit
#                                    resolution GET      /uchwaly/:id(.:format)                                                                   management/resolutions#show
#                                               PATCH    /uchwaly/:id(.:format)                                                                   management/resolutions#update
#                                               PUT      /uchwaly/:id(.:format)                                                                   management/resolutions#update
#                                               DELETE   /uchwaly/:id(.:format)                                                                   management/resolutions#destroy
#                                      settings GET      /ustawienia(.:format)                                                                    management/settings#index
#                                  edit_setting GET      /ustawienia/:id/edit(.:format)                                                           management/settings#edit
#                                       setting PATCH    /ustawienia/:id(.:format)                                                                management/settings#update
#                                               PUT      /ustawienia/:id(.:format)                                                                management/settings#update
#                     glosowania_pelnomocnictwo GET      /glosowania/pelnomocnictwo(.:format)                                                     management/voting/commissions#new
#                                   commissions POST     /commissions(.:format)                                                                   management/voting/commissions#create
#                                new_commission GET      /commissions/new(.:format)                                                               management/voting/commissions#new
#                                case_presences POST     /case_presences(.:format)                                                                management/voting/case_presences#create
#                                 case_presence DELETE   /case_presences/:id(.:format)                                                            management/voting/case_presences#destroy
#                                   walne_cases GET      /glosowania/walne(.:format)                                                              management/voting/cases#walne
#                                  obecni_cases GET      /glosowania/obecni(.:format)                                                             management/voting/cases#obecni
#                                  accept_cases POST     /glosowania/accept(.:format)                                                             management/voting/cases#accept
#                                         votes GET      /glosowania/:id/votes(.:format)                                                          management/voting/votes#index
#                                               POST     /glosowania/:id/votes(.:format)                                                          management/voting/votes#create
#                                      new_vote GET      /glosowania/:id/votes/new(.:format)                                                      management/voting/votes#new
#                                     edit_vote GET      /glosowania/:id/votes/:id/edit(.:format)                                                 management/voting/votes#edit
#                                          vote GET      /glosowania/:id/votes/:id(.:format)                                                      management/voting/votes#show
#                                               PATCH    /glosowania/:id/votes/:id(.:format)                                                      management/voting/votes#update
#                                               PUT      /glosowania/:id/votes/:id(.:format)                                                      management/voting/votes#update
#                                               DELETE   /glosowania/:id/votes/:id(.:format)                                                      management/voting/votes#destroy
#                                  approve_case GET      /glosowania/:id/approve(.:format)                                                        management/voting/cases#approve
#                                  abstain_case GET      /glosowania/:id/abstain(.:format)                                                        management/voting/cases#abstain
#                          approve_for_all_case PUT      /glosowania/:id/approve_for_all(.:format)                                                management/voting/cases#approve_for_all
#                                     hide_case PUT      /glosowania/:id/hide(.:format)                                                           management/voting/cases#hide
#                                unapprove_case GET      /glosowania/:id/unapprove(.:format)                                                      management/voting/cases#unapprove
#                                         cases GET      /glosowania(.:format)                                                                    management/voting/cases#index
#                                               POST     /glosowania(.:format)                                                                    management/voting/cases#create
#                                      new_case GET      /glosowania/new(.:format)                                                                management/voting/cases#new
#                                     edit_case GET      /glosowania/:id/edit(.:format)                                                           management/voting/cases#edit
#                                          case GET      /glosowania/:id(.:format)                                                                management/voting/cases#show
#                                               PATCH    /glosowania/:id(.:format)                                                                management/voting/cases#update
#                                               PUT      /glosowania/:id(.:format)                                                                management/voting/cases#update
#                                               DELETE   /glosowania/:id(.:format)                                                                management/voting/cases#destroy
#                              api_informations GET      /api/informations(.:format)                                                              management/news/api/informations#index
#                                  informations GET      /informacje(.:format)                                                                    management/news/informations#index
#                                               POST     /informacje(.:format)                                                                    management/news/informations#create
#                               new_information GET      /informacje/new(.:format)                                                                management/news/informations#new
#                              edit_information GET      /informacje/:id/edit(.:format)                                                           management/news/informations#edit
#                                   information GET      /informacje/:id(.:format)                                                                management/news/informations#show
#                                               PATCH    /informacje/:id(.:format)                                                                management/news/informations#update
#                                               PUT      /informacje/:id(.:format)                                                                management/news/informations#update
#                                               DELETE   /informacje/:id(.:format)                                                                management/news/informations#destroy
#       unpaid_membership_admin_membership_fees GET      /membership/admin/membership_fees/unpaid(.:format)                                       membership/admin/membership_fees#unpaid
# check_emails_membership_admin_membership_fees POST     /membership/admin/membership_fees/check_emails(.:format)                                 membership/admin/membership_fees#check_emails
#              callback_activities_strava_index GET      /activities/strava/callback(.:format)                                                    training/activities/strava#callback
#                       activities_strava_index GET      /activities/strava(.:format)                                                             training/activities/strava#index
#                                               POST     /activities/strava(.:format)                                                             training/activities/strava#create
#                         new_activities_strava GET      /activities/strava/new(.:format)                                                         training/activities/strava#new
#          activities_api_mountain_route_points GET      /activities/api/mountain_route_points(.:format)                                          training/activities/api/mountain_route_points#index
#                                               POST     /activities/api/mountain_route_points(.:format)                                          training/activities/api/mountain_route_points#create
#       new_activities_api_mountain_route_point GET      /activities/api/mountain_route_points/new(.:format)                                      training/activities/api/mountain_route_points#new
#      edit_activities_api_mountain_route_point GET      /activities/api/mountain_route_points/:id/edit(.:format)                                 training/activities/api/mountain_route_points#edit
#           activities_api_mountain_route_point GET      /activities/api/mountain_route_points/:id(.:format)                                      training/activities/api/mountain_route_points#show
#                                               PATCH    /activities/api/mountain_route_points/:id(.:format)                                      training/activities/api/mountain_route_points#update
#                                               PUT      /activities/api/mountain_route_points/:id(.:format)                                      training/activities/api/mountain_route_points#update
#                                               DELETE   /activities/api/mountain_route_points/:id(.:format)                                      training/activities/api/mountain_route_points#destroy
#     callback_activities_api_strava_activities GET      /activities/api/strava_activities/callback(.:format)                                     training/activities/api/strava_activities#subscribe
#                                               POST     /activities/api/strava_activities/callback(.:format)                                     training/activities/api/strava_activities#callback
#              activities_api_strava_activities GET      /activities/api/strava_activities(.:format)                                              training/activities/api/strava_activities#index
#                                               POST     /activities/api/strava_activities(.:format)                                              training/activities/api/strava_activities#create
#                activities_api_mountain_routes GET      /activities/api/mountain_routes(.:format)                                                training/activities/api/mountain_routes#index
#                          activities_api_boars GET      /activities/api/boars(.:format)                                                          training/activities/api/boars#index
#                         activities_ski_routes GET      /activities/ski_routes(.:format)                                                         training/activities/ski_routes#index
#                                               POST     /activities/ski_routes(.:format)                                                         training/activities/ski_routes#create
#                      new_activities_ski_route GET      /activities/ski_routes/new(.:format)                                                     training/activities/ski_routes#new
#                     edit_activities_ski_route GET      /activities/ski_routes/:id/edit(.:format)                                                training/activities/ski_routes#edit
#                          activities_ski_route GET      /activities/ski_routes/:id(.:format)                                                     training/activities/ski_routes#show
#                                               PATCH    /activities/ski_routes/:id(.:format)                                                     training/activities/ski_routes#update
#                                               PUT      /activities/ski_routes/:id(.:format)                                                     training/activities/ski_routes#update
#                                               DELETE   /activities/ski_routes/:id(.:format)                                                     training/activities/ski_routes#destroy
#                          activities_contracts GET      /activities/contracts(.:format)                                                          training/activities/contracts#index
#                                               POST     /activities/contracts(.:format)                                                          training/activities/contracts#create
#                       new_activities_contract GET      /activities/contracts/new(.:format)                                                      training/activities/contracts#new
#                      edit_activities_contract GET      /activities/contracts/:id/edit(.:format)                                                 training/activities/contracts#edit
#                           activities_contract GET      /activities/contracts/:id(.:format)                                                      training/activities/contracts#show
#                                               PATCH    /activities/contracts/:id(.:format)                                                      training/activities/contracts#update
#                                               PUT      /activities/contracts/:id(.:format)                                                      training/activities/contracts#update
#                                               DELETE   /activities/contracts/:id(.:format)                                                      training/activities/contracts#destroy
#                     activities_user_contracts POST     /activities/user_contracts(.:format)                                                     training/activities/user_contracts#create
#                      activities_user_contract DELETE   /activities/user_contracts/:id(.:format)                                                 training/activities/user_contracts#destroy
#                              activities_heart POST     /activities/heart(.:format)                                                              training/activities/hearts#heart
#                            activities_unheart DELETE   /activities/unheart(.:format)                                                            training/activities/hearts#unheart
#                      questionare_snw_profiles POST     /questionare/snw_profiles(.:format)                                                      training/questionare/snw_profiles#create
#                   new_questionare_snw_profile GET      /questionare/snw_profiles/new(.:format)                                                  training/questionare/snw_profiles#new
#          training_supplementary_course_record GET      /wydarzenia/:id(.:format)                                                                training/supplementary/courses#show
#                     supplementary_api_courses GET      /supplementary/api/courses(.:format)                                                     training/supplementary/api/courses#index
#                 supplementary_course_packages POST     /supplementary/courses/:course_id/packages(.:format)                                     training/supplementary/packages#create
#              new_supplementary_course_package GET      /supplementary/courses/:course_id/packages/new(.:format)                                 training/supplementary/packages#new
#                archived_supplementary_courses GET      /supplementary/courses/archived(.:format)                                                training/supplementary/courses#archived
#                         supplementary_courses GET      /supplementary/courses(.:format)                                                         training/supplementary/courses#index
#                                               POST     /supplementary/courses(.:format)                                                         training/supplementary/courses#create
#                      new_supplementary_course GET      /supplementary/courses/new(.:format)                                                     training/supplementary/courses#new
#                     edit_supplementary_course GET      /supplementary/courses/:id/edit(.:format)                                                training/supplementary/courses#edit
#                          supplementary_course GET      /supplementary/courses/:id(.:format)                                                     training/supplementary/courses#show
#                                               PATCH    /supplementary/courses/:id(.:format)                                                     training/supplementary/courses#update
#                                               PUT      /supplementary/courses/:id(.:format)                                                     training/supplementary/courses#update
#                                               DELETE   /supplementary/courses/:id(.:format)                                                     training/supplementary/courses#destroy
#              send_email_supplementary_sign_up PUT      /supplementary/sign_ups/:id/send_email(.:format)                                         training/supplementary/sign_ups#send_email
#     cancel_cash_payment_supplementary_sign_up PUT      /supplementary/sign_ups/:id/cancel_cash_payment(.:format)                                training/supplementary/sign_ups#cancel_cash_payment
#                 cancel_supplementary_sign_ups GET      /supplementary/sign_ups/cancel(.:format)                                                 training/supplementary/sign_ups#cancel
#               manually_supplementary_sign_ups PUT      /supplementary/sign_ups/manually(.:format)                                               training/supplementary/sign_ups#manually
#                        supplementary_sign_ups GET      /supplementary/sign_ups(.:format)                                                        training/supplementary/sign_ups#index
#                                               POST     /supplementary/sign_ups(.:format)                                                        training/supplementary/sign_ups#create
#                     new_supplementary_sign_up GET      /supplementary/sign_ups/new(.:format)                                                    training/supplementary/sign_ups#new
#                    edit_supplementary_sign_up GET      /supplementary/sign_ups/:id/edit(.:format)                                               training/supplementary/sign_ups#edit
#                         supplementary_sign_up GET      /supplementary/sign_ups/:id(.:format)                                                    training/supplementary/sign_ups#show
#                                               PATCH    /supplementary/sign_ups/:id(.:format)                                                    training/supplementary/sign_ups#update
#                                               PUT      /supplementary/sign_ups/:id(.:format)                                                    training/supplementary/sign_ups#update
#                                               DELETE   /supplementary/sign_ups/:id(.:format)                                                    training/supplementary/sign_ups#destroy
#                                     kontrakty GET      /narciarskie-dziki/kontrakty(.:format)                                                   training/activities/contracts#index
#                                   narciarstwo GET      /przejscia/narciarstwo(.:format)                                                         training/activities/ski_routes#new
#                                    wspinaczka GET      /przejscia/wspinaczka(.:format)                                                          activities/mountain_routes#new
#                                    ski_events GET      /wydarzenia/narciarskie(.:format)                                                        training/supplementary/courses#index {:category=>"snw"}
#                               climbing_events GET      /wydarzenia/wspinaczkowe(.:format)                                                       training/supplementary/courses#index {:category=>"sww"}
#                                    web_events GET      /wydarzenia/webinary(.:format)                                                           training/supplementary/courses#index {:category=>"web"}
#                                    wydarzenia GET      /wydarzenia(.:format)                                                                    training/supplementary/courses#index
#                                  polish_event GET      /wydarzenia/*id(.:format)                                                                training/supplementary/courses#show
#                             polish_event_slug GET      /wydarzenia/*slug(.:format)                                                              training/supplementary/courses#show
#                           polish_event_cancel GET      /wydarzenie/wypisz/*code(.:format)                                                       training/supplementary/sign_ups#cancel
#                                     donations GET      /donations(.:format)                                                                     charity/donations#index
#                                               POST     /donations(.:format)                                                                     charity/donations#create
#                                  new_donation GET      /donations/new(.:format)                                                                 charity/donations#new
#                                 edit_donation GET      /donations/:id/edit(.:format)                                                            charity/donations#edit
#                                      donation GET      /donations/:id(.:format)                                                                 charity/donations#show
#                                               PATCH    /donations/:id(.:format)                                                                 charity/donations#update
#                                               PUT      /donations/:id(.:format)                                                                 charity/donations#update
#                                               DELETE   /donations/:id(.:format)                                                                 charity/donations#destroy
#                               admin_donations GET      /admin/donations(.:format)                                                               charity/admin/donations#index
#                                     darowizny GET      /darowizny(.:format)                                                                     charity/donations#new
#                                       mariusz GET      /dla-mariusza(.:format)                                                                  charity/donations#new
#                                       na_ryse GET      /na-ryse(.:format)                                                                       charity/donations#new
#                             serwis_narciarski GET      /serwis-narciarski(.:format)                                                             charity/donations#new
#                                ksiazka_karola GET      /ksiazka-karola(.:format)                                                                charity/donations#new
#                        accept_edition_request PUT      /editions/:edition_id/requests/:id/accept(.:format)                                      photo_competition/requests#accept
#                              edition_requests GET      /editions/:edition_id/requests(.:format)                                                 photo_competition/requests#index
#                                               POST     /editions/:edition_id/requests(.:format)                                                 photo_competition/requests#create
#                           new_edition_request GET      /editions/:edition_id/requests/new(.:format)                                             photo_competition/requests#new
#                          edit_edition_request GET      /editions/:edition_id/requests/:id/edit(.:format)                                        photo_competition/requests#edit
#                               edition_request GET      /editions/:edition_id/requests/:id(.:format)                                             photo_competition/requests#show
#                                               PATCH    /editions/:edition_id/requests/:id(.:format)                                             photo_competition/requests#update
#                                               PUT      /editions/:edition_id/requests/:id(.:format)                                             photo_competition/requests#update
#                                               DELETE   /editions/:edition_id/requests/:id(.:format)                                             photo_competition/requests#destroy
#                                       edition GET      /editions/:id(.:format)                                                                  photo_competition/editions#show
#                                admin_editions GET      /admin/editions(.:format)                                                                photo_competition/admin/editions#index
#                                               POST     /admin/editions(.:format)                                                                photo_competition/admin/editions#create
#                             new_admin_edition GET      /admin/editions/new(.:format)                                                            photo_competition/admin/editions#new
#                            edit_admin_edition GET      /admin/editions/:id/edit(.:format)                                                       photo_competition/admin/editions#edit
#                                 admin_edition GET      /admin/editions/:id(.:format)                                                            photo_competition/admin/editions#show
#                                               PATCH    /admin/editions/:id(.:format)                                                            photo_competition/admin/editions#update
#                                               PUT      /admin/editions/:id(.:format)                                                            photo_competition/admin/editions#update
#                                               DELETE   /admin/editions/:id(.:format)                                                            photo_competition/admin/editions#destroy
#                                               GET      /konkurs/:edition_id(.:format)                                                           photo_competition/requests#new
#                                               GET      /konkurs/:edition_code/glosowanie(.:format)                                              photo_competition/editions#show
#                               api_contractors GET      /api/contractors(.:format)                                                               settlement/api/contractors#index
#                                               POST     /api/contractors(.:format)                                                               settlement/api/contractors#create
#                            new_api_contractor GET      /api/contractors/new(.:format)                                                           settlement/api/contractors#new
#                           edit_api_contractor GET      /api/contractors/:id/edit(.:format)                                                      settlement/api/contractors#edit
#                                api_contractor GET      /api/contractors/:id(.:format)                                                           settlement/api/contractors#show
#                                               PATCH    /api/contractors/:id(.:format)                                                           settlement/api/contractors#update
#                                               PUT      /api/contractors/:id(.:format)                                                           settlement/api/contractors#update
#                                               DELETE   /api/contractors/:id(.:format)                                                           settlement/api/contractors#destroy
#                             admin_contractors GET      /admin/contractors(.:format)                                                             settlement/admin/contractors#index
#                                               POST     /admin/contractors(.:format)                                                             settlement/admin/contractors#create
#                          new_admin_contractor GET      /admin/contractors/new(.:format)                                                         settlement/admin/contractors#new
#                         edit_admin_contractor GET      /admin/contractors/:id/edit(.:format)                                                    settlement/admin/contractors#edit
#                              admin_contractor GET      /admin/contractors/:id(.:format)                                                         settlement/admin/contractors#show
#                                               PATCH    /admin/contractors/:id(.:format)                                                         settlement/admin/contractors#update
#                                               PUT      /admin/contractors/:id(.:format)                                                         settlement/admin/contractors#update
#                                               DELETE   /admin/contractors/:id(.:format)                                                         settlement/admin/contractors#destroy
#                           admin_project_items POST     /admin/project_items(.:format)                                                           settlement/admin/project_items#create
#                            admin_project_item PATCH    /admin/project_items/:id(.:format)                                                       settlement/admin/project_items#update
#                                               PUT      /admin/project_items/:id(.:format)                                                       settlement/admin/project_items#update
#                                 admin_incomes POST     /admin/incomes(.:format)                                                                 settlement/admin/incomes#create
#                           close_admin_project PUT      /admin/projects/:id/close(.:format)                                                      settlement/admin/projects#close
#                                admin_projects GET      /admin/projects(.:format)                                                                settlement/admin/projects#index
#                                               POST     /admin/projects(.:format)                                                                settlement/admin/projects#create
#                             new_admin_project GET      /admin/projects/new(.:format)                                                            settlement/admin/projects#new
#                            edit_admin_project GET      /admin/projects/:id/edit(.:format)                                                       settlement/admin/projects#edit
#                                 admin_project GET      /admin/projects/:id(.:format)                                                            settlement/admin/projects#show
#                                               PATCH    /admin/projects/:id(.:format)                                                            settlement/admin/projects#update
#                                               PUT      /admin/projects/:id(.:format)                                                            settlement/admin/projects#update
#                                               DELETE   /admin/projects/:id(.:format)                                                            settlement/admin/projects#destroy
#                       history_admin_contracts GET      /admin/contracts/history(.:format)                                                       settlement/admin/contracts#history
#                       archive_admin_contracts GET      /admin/contracts/archive(.:format)                                                       settlement/admin/contracts#archive
#            download_attachment_admin_contract GET      /admin/contracts/:id/download_attachment(.:format)                                       settlement/admin/contracts#download_attachment
#                         accept_admin_contract PUT      /admin/contracts/:id/accept(.:format)                                                    settlement/admin/contracts#accept
#                     prepayment_admin_contract PUT      /admin/contracts/:id/prepayment(.:format)                                                settlement/admin/contracts#prepayment
#                         finish_admin_contract PUT      /admin/contracts/:id/finish(.:format)                                                    settlement/admin/contracts#finish
#                               admin_contracts GET      /admin/contracts(.:format)                                                               settlement/admin/contracts#index
#                                               POST     /admin/contracts(.:format)                                                               settlement/admin/contracts#create
#                            new_admin_contract GET      /admin/contracts/new(.:format)                                                           settlement/admin/contracts#new
#                           edit_admin_contract GET      /admin/contracts/:id/edit(.:format)                                                      settlement/admin/contracts#edit
#                                admin_contract GET      /admin/contracts/:id(.:format)                                                           settlement/admin/contracts#show
#                                               PATCH    /admin/contracts/:id(.:format)                                                           settlement/admin/contracts#update
#                                               PUT      /admin/contracts/:id(.:format)                                                           settlement/admin/contracts#update
#                                               DELETE   /admin/contracts/:id(.:format)                                                           settlement/admin/contracts#destroy
#                                       rozlicz GET      /rozlicz(.:format)                                                                       settlement/admin/contracts#new
#                                   rozliczenia GET      /rozliczenia(.:format)                                                                   settlement/admin/contracts#index
#                                               GET      /rozliczenia/analiza/:year(.:format)                                                     settlement/admin/contracts#analiza
#                           accept_profile_list POST     /profiles/:profile_id/lists/:id/accept(.:format)                                         user_management/lists#accept
#                                 profile_lists GET      /profiles/:profile_id/lists(.:format)                                                    user_management/lists#index
#                                               POST     /profiles/:profile_id/lists(.:format)                                                    user_management/lists#create
#                              new_profile_list GET      /profiles/:profile_id/lists/new(.:format)                                                user_management/lists#new
#                             edit_profile_list GET      /profiles/:profile_id/lists/:id/edit(.:format)                                           user_management/lists#edit
#                                  profile_list GET      /profiles/:profile_id/lists/:id(.:format)                                                user_management/lists#show
#                                               PATCH    /profiles/:profile_id/lists/:id(.:format)                                                user_management/lists#update
#                                               PUT      /profiles/:profile_id/lists/:id(.:format)                                                user_management/lists#update
#                                               DELETE   /profiles/:profile_id/lists/:id(.:format)                                                user_management/lists#destroy
#                                    admin_tags GET      /admin/tags(.:format)                                                                    library/admin/tags#index
#                                               POST     /admin/tags(.:format)                                                                    library/admin/tags#create
#                                 new_admin_tag GET      /admin/tags/new(.:format)                                                                library/admin/tags#new
#                                edit_admin_tag GET      /admin/tags/:id/edit(.:format)                                                           library/admin/tags#edit
#                                     admin_tag GET      /admin/tags/:id(.:format)                                                                library/admin/tags#show
#                                               PATCH    /admin/tags/:id(.:format)                                                                library/admin/tags#update
#                                               PUT      /admin/tags/:id(.:format)                                                                library/admin/tags#update
#                                               DELETE   /admin/tags/:id(.:format)                                                                library/admin/tags#destroy
#                       biblioteka_wypozyczenia GET      /biblioteka/wypozyczenia(.:format)                                                       library/item_reservations#index {:params=>{:q=>{:back_at_null=>true, :returned_at_lteq=>Thu, 25 Jan 2024}}}
#                                 library_items GET      /library/items(.:format)                                                                 library/items#index
#                                               POST     /library/items(.:format)                                                                 library/items#create
#                              new_library_item GET      /library/items/new(.:format)                                                             library/items#new
#                             edit_library_item GET      /library/items/:id/edit(.:format)                                                        library/items#edit
#                                  library_item GET      /library/items/:id(.:format)                                                             library/items#show
#                                               PATCH    /library/items/:id(.:format)                                                             library/items#update
#                                               PUT      /library/items/:id(.:format)                                                             library/items#update
#                                               DELETE   /library/items/:id(.:format)                                                             library/items#destroy
#                               library_authors GET      /library/authors(.:format)                                                               library/authors#index
#                                               POST     /library/authors(.:format)                                                               library/authors#create
#                            new_library_author GET      /library/authors/new(.:format)                                                           library/authors#new
#                           edit_library_author GET      /library/authors/:id/edit(.:format)                                                      library/authors#edit
#                                library_author GET      /library/authors/:id(.:format)                                                           library/authors#show
#                                               PATCH    /library/authors/:id(.:format)                                                           library/authors#update
#                                               PUT      /library/authors/:id(.:format)                                                           library/authors#update
#                                               DELETE   /library/authors/:id(.:format)                                                           library/authors#destroy
#               return_library_item_reservation PUT      /library/item_reservations/:id/return(.:format)                                          library/item_reservations#return
#               remind_library_item_reservation PUT      /library/item_reservations/:id/remind(.:format)                                          library/item_reservations#remind
#                     library_item_reservations GET      /library/item_reservations(.:format)                                                     library/item_reservations#index
#                                               POST     /library/item_reservations(.:format)                                                     library/item_reservations#create
#                  new_library_item_reservation GET      /library/item_reservations/new(.:format)                                                 library/item_reservations#new
#                 edit_library_item_reservation GET      /library/item_reservations/:id/edit(.:format)                                            library/item_reservations#edit
#                      library_item_reservation GET      /library/item_reservations/:id(.:format)                                                 library/item_reservations#show
#                                               PATCH    /library/item_reservations/:id(.:format)                                                 library/item_reservations#update
#                                               PUT      /library/item_reservations/:id(.:format)                                                 library/item_reservations#update
#                                               DELETE   /library/item_reservations/:id(.:format)                                                 library/item_reservations#destroy
#                                    biblioteka GET      /biblioteka(.:format)                                                                    library/items#index
#                                          tagi GET      /tagi(.:format)                                                                          library/admin/tags#index
#                                       ksiazka GET      /biblioteka/:id(.:format)                                                                library/items#show
#                                         autor GET      /biblioteka/autorzy/:id(.:format)                                                        library/authors#show
#                         business_course_types GET      /business/course_types(.:format)                                                         business/course_types#index
#                business_conversation_messages POST     /business/conversations/:conversation_id/messages(.:format)                              business/messages#create
#                        business_conversations POST     /business/conversations(.:format)                                                        business/conversations#create
#                       charge_business_payment POST     /business/payments/:id/charge(.:format)                                                  business/payments#charge
#                            ask_business_lists POST     /business/sign_ups/:id/lists/ask(.:format)                                               business/lists#ask
#                                business_lists POST     /business/sign_ups/:id/lists(.:format)                                                   business/lists#create
#                             new_business_list GET      /business/sign_ups/:id/lists/new(.:format)                                               business/lists#new
#                  send_second_business_sign_up POST     /business/sign_ups/:id/send_second(.:format)                                             business/sign_ups#send_second
#                             business_sign_ups GET      /business/sign_ups(.:format)                                                             business/sign_ups#index
#                                               POST     /business/sign_ups(.:format)                                                             business/sign_ups#create
#                          new_business_sign_up GET      /business/sign_ups/new(.:format)                                                         business/sign_ups#new
#                         edit_business_sign_up GET      /business/sign_ups/:id/edit(.:format)                                                    business/sign_ups#edit
#                              business_sign_up GET      /business/sign_ups/:id(.:format)                                                         business/sign_ups#show
#                                               PATCH    /business/sign_ups/:id(.:format)                                                         business/sign_ups#update
#                                               PUT      /business/sign_ups/:id(.:format)                                                         business/sign_ups#update
#                                               DELETE   /business/sign_ups/:id(.:format)                                                         business/sign_ups#destroy
#                                               GET      /business/lists(.:format)                                                                business/lists#index
#                               history_courses GET      /courses/history(.:format)                                                               business/courses#history
#                                 public_course GET      /courses/:id/public(.:format)                                                            business/courses#public
#                            seats_minus_course PUT      /courses/:id/seats_minus(.:format)                                                       business/courses#seats_minus
#                             seats_plus_course PUT      /courses/:id/seats_plus(.:format)                                                        business/courses#seats_plus
#                                       courses GET      /courses(.:format)                                                                       business/courses#index
#                                               POST     /courses(.:format)                                                                       business/courses#create
#                                    new_course GET      /courses/new(.:format)                                                                   business/courses#new
#                                   edit_course GET      /courses/:id/edit(.:format)                                                              business/courses#edit
#                                        course GET      /courses/:id(.:format)                                                                   business/courses#show
#                                               PATCH    /courses/:id(.:format)                                                                   business/courses#update
#                                               PUT      /courses/:id(.:format)                                                                   business/courses#update
#                                               DELETE   /courses/:id(.:format)                                                                   business/courses#destroy
#                                   api_courses GET      /api/courses(.:format)                                                                   business/api/courses#index
#                                 business_list GET      /zapotrzebowanie/:id(.:format)                                                           business/lists#new
#                 business_course_record_public GET      /kursy/:id(.:format)                                                                     business/courses#public
#                        business_course_record GET      /courses/:id(.:format)                                                                   business/courses#show
#                               api_snw_applies GET      /api/snw_applies(.:format)                                                               management/snw/api/snw_applies#index
#                                               POST     /api/snw_applies(.:format)                                                               management/snw/api/snw_applies#create
#                             new_api_snw_apply GET      /api/snw_applies/new(.:format)                                                           management/snw/api/snw_applies#new
#                            edit_api_snw_apply GET      /api/snw_applies/:id/edit(.:format)                                                      management/snw/api/snw_applies#edit
#                                 api_snw_apply GET      /api/snw_applies/:id(.:format)                                                           management/snw/api/snw_applies#show
#                                               PATCH    /api/snw_applies/:id(.:format)                                                           management/snw/api/snw_applies#update
#                                               PUT      /api/snw_applies/:id(.:format)                                                           management/snw/api/snw_applies#update
#                                               DELETE   /api/snw_applies/:id(.:format)                                                           management/snw/api/snw_applies#destroy
#                                   snw_applies GET      /snw_applies(.:format)                                                                   management/snw/snw_applies#index
#                                               POST     /snw_applies(.:format)                                                                   management/snw/snw_applies#create
#                                 new_snw_apply GET      /snw_applies/new(.:format)                                                               management/snw/snw_applies#new
#                                edit_snw_apply GET      /snw_applies/:id/edit(.:format)                                                          management/snw/snw_applies#edit
#                                     snw_apply GET      /snw_applies/:id(.:format)                                                               management/snw/snw_applies#show
#                                               PATCH    /snw_applies/:id(.:format)                                                               management/snw/snw_applies#update
#                                               PUT      /snw_applies/:id(.:format)                                                               management/snw/snw_applies#update
#                                               DELETE   /snw_applies/:id(.:format)                                                               management/snw/snw_applies#destroy
#                                snw_zgloszenie GET      /snw/zgloszenie(.:format)                                                                management/snw/snw_applies#new
#                                snw_apply_page GET      /snw/zgloszenie/:id(.:format)                                                            management/snw/snw_applies#show
#                                   api_authors GET      /api/authors(.:format)                                                                   blog/api/authors#index
#                                               POST     /api/authors(.:format)                                                                   blog/api/authors#create
#                                new_api_author GET      /api/authors/new(.:format)                                                               blog/api/authors#new
#                               edit_api_author GET      /api/authors/:id/edit(.:format)                                                          blog/api/authors#edit
#                                    api_author GET      /api/authors/:id(.:format)                                                               blog/api/authors#show
#                                               PATCH    /api/authors/:id(.:format)                                                               blog/api/authors#update
#                                               PUT      /api/authors/:id(.:format)                                                               blog/api/authors#update
#                                               DELETE   /api/authors/:id(.:format)                                                               blog/api/authors#destroy
#                           api_dashboard_index GET      /api/dashboard(.:format)                                                                 blog/api/dashboard#index
#                                               POST     /api/dashboard(.:format)                                                                 blog/api/dashboard#create
#                             new_api_dashboard GET      /api/dashboard/new(.:format)                                                             blog/api/dashboard#new
#                            edit_api_dashboard GET      /api/dashboard/:id/edit(.:format)                                                        blog/api/dashboard#edit
#                                 api_dashboard GET      /api/dashboard/:id(.:format)                                                             blog/api/dashboard#show
#                                               PATCH    /api/dashboard/:id(.:format)                                                             blog/api/dashboard#update
#                                               PUT      /api/dashboard/:id(.:format)                                                             blog/api/dashboard#update
#                                               DELETE   /api/dashboard/:id(.:format)                                                             blog/api/dashboard#destroy
#                             prezentacje_zglos GET      /prezentacje/zglos(.:format)                                                             club_meetings/ideas#new
#                                         ideas GET      /ideas(.:format)                                                                         club_meetings/ideas#index
#                                               POST     /ideas(.:format)                                                                         club_meetings/ideas#create
#                                      new_idea GET      /ideas/new(.:format)                                                                     club_meetings/ideas#new
#                                     edit_idea GET      /ideas/:id/edit(.:format)                                                                club_meetings/ideas#edit
#                                          idea GET      /ideas/:id(.:format)                                                                     club_meetings/ideas#show
#                                               PATCH    /ideas/:id(.:format)                                                                     club_meetings/ideas#update
#                                               PUT      /ideas/:id(.:format)                                                                     club_meetings/ideas#update
#                                               DELETE   /ideas/:id(.:format)                                                                     club_meetings/ideas#destroy
#                                        photos GET      /photos(.:format)                                                                        photos#index
#                                         likes POST     /likes(.:format)                                                                         likes#create
#                                          like DELETE   /likes/:id(.:format)                                                                     likes#destroy
#                                               GET      /przejscia/photos/:year/:month(.:format)                                                 activities/mountain_routes#photos
#                hide_activities_mountain_route PUT      /przejscia/:id/hide(.:format)                                                            activities/mountain_routes#hide
#                    activities_mountain_routes GET      /przejscia(.:format)                                                                     activities/mountain_routes#index
#                                               POST     /przejscia(.:format)                                                                     activities/mountain_routes#create
#                 new_activities_mountain_route GET      /przejscia/new(.:format)                                                                 activities/mountain_routes#new
#                edit_activities_mountain_route GET      /przejscia/:id/edit(.:format)                                                            activities/mountain_routes#edit
#                     activities_mountain_route GET      /przejscia/:id(.:format)                                                                 activities/mountain_routes#show
#                                               PATCH    /przejscia/:id(.:format)                                                                 activities/mountain_routes#update
#                                               PUT      /przejscia/:id(.:format)                                                                 activities/mountain_routes#update
#                                               DELETE   /przejscia/:id(.:format)                                                                 activities/mountain_routes#destroy
#                              active_api_users GET      /api/users/active(.:format)                                                              api/users#active
#                                      api_user GET      /api/users/:id(.:format)                                                                 api/users#show
#                           status_api_payments POST     /api/payments/status(.:format)                                                           api/payments#status
#                        thank_you_api_payments POST     /api/payments/thank_you(.:format)                                                        api/payments#thank_you
#                         reactivation_profiles GET      /profiles/reactivation(.:format)                                                         profiles#reactivation
#                           reactivate_profiles PUT      /profiles/reactivate(.:format)                                                           profiles#reactivate
#                                      profiles GET      /profiles(.:format)                                                                      profiles#index
#                                               POST     /profiles(.:format)                                                                      profiles#create
#                                   new_profile GET      /profiles/new(.:format)                                                                  profiles#new
#                                       profile GET      /profiles/:id(.:format)                                                                  profiles#show
#                       delete_item_reservation DELETE   /reservations/:id/delete_item(.:format)                                                  reservations#delete_item
#                     availability_reservations POST     /reservations/availability(.:format)                                                     reservations#availability
#                                  reservations GET      /reservations(.:format)                                                                  reservations#index
#                                               POST     /reservations(.:format)                                                                  reservations#create
#                               new_reservation GET      /reservations/new(.:format)                                                              reservations#new
#                                refund_payment POST     /payments/:id/refund(.:format)                                                           payments#refund
#                          mark_as_paid_payment PUT      /payments/:id/mark_as_paid(.:format)                                                     payments#mark_as_paid
#                                charge_payment GET      /payments/:id/charge(.:format)                                                           payments#charge
#                                      payments GET      /payments(.:format)                                                                      payments#index
#                               membership_fees GET      /klub/skladki(.:format)                                                                  membership/fees#index
#                                               POST     /klub/skladki(.:format)                                                                  membership/fees#create
#                                membership_fee DELETE   /klub/skladki/:id(.:format)                                                              membership/fees#destroy
#                                         admin GET      /admin(.:format)                                                                         admin/dashboard#index
#                          revert_admin_version POST     /admin/versions/:id/revert(.:format)                                                     admin/versions#revert
#                                admin_versions GET      /admin/versions(.:format)                                                                admin/versions#index
#                general_meeting_admin_profiles GET      /admin/profiles/general_meeting(.:format)                                                admin/profiles#general_meeting
#                          accept_admin_profile PUT      /admin/profiles/:id/accept(.:format)                                                     admin/profiles#accept
#                      send_email_admin_profile PUT      /admin/profiles/:id/send_email(.:format)                                                 admin/profiles#send_email
#                                admin_profiles GET      /admin/profiles(.:format)                                                                admin/profiles#index
#                                               POST     /admin/profiles(.:format)                                                                admin/profiles#create
#                             new_admin_profile GET      /admin/profiles/new(.:format)                                                            admin/profiles#new
#                            edit_admin_profile GET      /admin/profiles/:id/edit(.:format)                                                       admin/profiles#edit
#                                 admin_profile GET      /admin/profiles/:id(.:format)                                                            admin/profiles#show
#                                               PATCH    /admin/profiles/:id(.:format)                                                            admin/profiles#update
#                                               PUT      /admin/profiles/:id(.:format)                                                            admin/profiles#update
#                                               DELETE   /admin/profiles/:id(.:format)                                                            admin/profiles#destroy
#                  import_admin_importing_index POST     /admin/importing/import(.:format)                                                        admin/importing#import
#                         admin_importing_index GET      /admin/importing(.:format)                                                               admin/importing#index
#                             become_admin_user POST     /admin/users/:id/become(.:format)                                                        admin/users#become
#                         make_admin_admin_user GET      /admin/users/:id/make_admin(.:format)                                                    admin/users#make_admin
#                       cancel_admin_admin_user GET      /admin/users/:id/cancel_admin(.:format)                                                  admin/users#cancel_admin
#                       make_curator_admin_user GET      /admin/users/:id/make_curator(.:format)                                                  admin/users#make_curator
#                     cancel_curator_admin_user GET      /admin/users/:id/cancel_curator(.:format)                                                admin/users#cancel_curator
#                                   admin_users GET      /admin/users(.:format)                                                                   admin/users#index
#                                               POST     /admin/users(.:format)                                                                   admin/users#create
#                                new_admin_user GET      /admin/users/new(.:format)                                                               admin/users#new
#                               edit_admin_user GET      /admin/users/:id/edit(.:format)                                                          admin/users#edit
#                                    admin_user GET      /admin/users/:id(.:format)                                                               admin/users#show
#                                               PATCH    /admin/users/:id(.:format)                                                               admin/users#update
#                                               PUT      /admin/users/:id(.:format)                                                               admin/users#update
#                                               DELETE   /admin/users/:id(.:format)                                                               admin/users#destroy
#                         admin_membership_fees GET      /admin/membership_fees(.:format)                                                         admin/membership_fees#index
#                                               POST     /admin/membership_fees(.:format)                                                         admin/membership_fees#create
#                          admin_membership_fee DELETE   /admin/membership_fees/:id(.:format)                                                     admin/membership_fees#destroy
#                       update_owner_admin_item PUT      /admin/items/:id/update_owner(.:format)                                                  admin/items#update_owner
#                    update_editable_admin_item PUT      /admin/items/:id/update_editable(.:format)                                               admin/items#update_editable
#                    toggle_rentable_admin_item PUT      /admin/items/:id/toggle_rentable(.:format)                                               admin/items#toggle_rentable
#                                   admin_items GET      /admin/items(.:format)                                                                   admin/items#index
#                                               POST     /admin/items(.:format)                                                                   admin/items#create
#                                new_admin_item GET      /admin/items/new(.:format)                                                               admin/items#new
#                               edit_admin_item GET      /admin/items/:id/edit(.:format)                                                          admin/items#edit
#                                    admin_item GET      /admin/items/:id(.:format)                                                               admin/items#show
#                                               PATCH    /admin/items/:id(.:format)                                                               admin/items#update
#                                               PUT      /admin/items/:id(.:format)                                                               admin/items#update
#                                               DELETE   /admin/items/:id(.:format)                                                               admin/items#destroy
#                     archive_admin_reservation PUT      /admin/reservations/:id/archive(.:format)                                                admin/reservations#archive
#                      charge_admin_reservation PUT      /admin/reservations/:id/charge(.:format)                                                 admin/reservations#charge
#                        give_admin_reservation PUT      /admin/reservations/:id/give(.:format)                                                   admin/reservations#give
#                      remind_admin_reservation POST     /admin/reservations/:id/remind(.:format)                                                 admin/reservations#remind
#                give_warning_admin_reservation POST     /admin/reservations/:id/give_warning(.:format)                                           admin/reservations#give_warning
#           give_back_warning_admin_reservation POST     /admin/reservations/:id/give_back_warning(.:format)                                      admin/reservations#give_back_warning
#                            admin_reservations GET      /admin/reservations(.:format)                                                            admin/reservations#index
#                        edit_admin_reservation GET      /admin/reservations/:id/edit(.:format)                                                   admin/reservations#edit
#                             admin_reservation PATCH    /admin/reservations/:id(.:format)                                                        admin/reservations#update
#                                               PUT      /admin/reservations/:id(.:format)                                                        admin/reservations#update
#                                               DELETE   /admin/reservations/:id(.:format)                                                        admin/reservations#destroy
#                                  update_items PUT      /reservations/items(.:format)                                                            reservations/items#update
#                                          user GET      /klubowicze/:kw_id(.:format)                                                             users#show
#                                         users GET      /klubowicze(.:format)                                                                    users#index
#                                               GET      /                                                                                        activities/mountain_routes#index
#                                       reserve GET      /zarezerwuj(.:format)                                                                    reservations#new
#                                    zgloszenie GET      /zgloszenie(.:format)                                                                    profiles#new
#                                   application GET      /application(.:format)                                                                   profiles#new {:locale=>:en}
#                                    pages_home GET      /pages/home(.:format)                                                                    pages#show {:id=>"home"}
#                                   pages_rules GET      /pages/rules(.:format)                                                                   pages#show {:id=>"rules"}
#                                          page GET      /pages/*id                                                                               pages#show
#                                 admin_dostepy GET      /admin/dostepy(.:format)                                                                 pages#show {:id=>"roles"}
#                                 trening_skimo GET      /trening/skimo(.:format)                                                                 pages#show {:id=>"skimo"}
#                                          root GET      /                                                                                        pages#show {:id=>"home"}
#                            rails_service_blob GET      /rails/active_storage/blobs/:signed_id/*filename(.:format)                               active_storage/blobs#show
#                     rails_blob_representation GET      /rails/active_storage/representations/:signed_blob_id/:variation_key/*filename(.:format) active_storage/representations#show
#                            rails_disk_service GET      /rails/active_storage/disk/:encoded_key/*filename(.:format)                              active_storage/disk#show
#                     update_rails_disk_service PUT      /rails/active_storage/disk/:encoded_token(.:format)                                      active_storage/disk#update
#                          rails_direct_uploads POST     /rails/active_storage/direct_uploads(.:format)                                           active_storage/direct_uploads#create

require 'sidekiq/web'
Rails.application.routes.draw do

  devise_for :users,
    class_name: 'Db::User',
    controllers: {
      registrations: 'registrations'
    }

  devise_scope :user do
    get '/zaloguj', to: 'devise/sessions#new'
    get '/zarejestruj', to: 'devise/registrations#new'
  end

  authenticate :user, lambda { |u| u.admin? } do
    mount Sidekiq::Web => '/sidekiq'
  end

  get 'wiadomosci' => 'messaging/conversations#index'
  get 'wypozyczalnia/regulamin' => 'pages#show', id: 'rules'
  get 'biblioteka/regulamin' => 'pages#show', id: 'rules'
  get 'serwis-narciarski/regulamin' => 'pages#show', id: 'rules'
  get 'wydarzenia/regulamin' => 'pages#show', id: 'rules'
  get 'glosowania/dane-osobowe' => 'pages#show', id: 'rules'
  get 'glosowania/instrukcja' => 'pages#show', id: 'rules'
  get 'narciarskie-dziki/regulamin' => 'pages#show', id: 'rules'
  get 'liga-tradowa/regulamin' => 'pages#show', id: 'rules'
  get 'osemka/regulamin' => 'pages#show', id: 'rules'
  get 'konkurs_kasprzyka/regulamin' => 'pages#show', id: 'rules'
  get 'instrukcje/wydarzenia' => 'pages#show', id: 'rules'
  get 'kontakty' => 'pages#show', id: 'kontakty'
  get '/wydarzenia/webinary', to: redirect { |path_params, req| "/supplementary/courses?category=web" }
  get '/marketing', to: redirect { |path_params, req| "/sponsorship_requests" }

  draw(:custom_endpoints)
  draw(:profile_creation_endpoints)
  draw(:charity_endpoints)

  resources :photos, only: :index
  resources :likes, only: %i[create destroy]

  namespace :activities, path: '/' do
    resources :mountain_routes, path: 'przejscia' do
      collection do
        get 'photos/:year/:month', to: 'mountain_routes#photos'
      end
      member do
        put :hide
      end
    end
  end

  namespace :api do
    resources :users, only: [:show] do
      collection do 
        get :active
      end
    end
    resources :payments, only: [] do
      collection do
        post :status
        post :thank_you
      end
    end
  end

  resources :profiles, only: [:index, :new, :create, :show] do
    collection do
      get :reactivation
      put :reactivate
    end
  end

  resources :reservations, only: [:index, :new, :create] do
    member do
      delete :delete_item
    end
    collection do
      post :availability
    end
  end

  resources :payments, only: [:index] do
    member do
      post :refund
      put :mark_as_paid
      get :charge
    end
  end

  namespace :membership, path: 'klub' do
    resources :fees, path: 'skladki', only: [:index, :create, :destroy]
  end

  namespace :admin do
    get '', to: 'dashboard#index', as: '/'

    resources :versions, only: :index do
      member do
        post :revert
      end
    end

    resources :profiles do
      collection do
        get :general_meeting
      end
      member do
        put :accept
        put :send_email
      end
    end
    resources :importing, only: [:index] do
      collection do
        post :import
      end
    end
    resources :users do
      member do
        post :become
        get :make_admin
        get :cancel_admin
        get :make_curator
        get :cancel_curator
      end
    end
    resources :membership_fees, only: %w(index create destroy)
    resources :items do
      member do
        put :update_owner
        put :update_editable
        put :toggle_rentable
      end
    end
    resources :reservations, only: %w(index edit update destroy) do
      member do
        put :archive
        put :charge
        put :give
        post :remind
        post :give_warning
        post :give_back_warning
      end
    end
  end

  put 'reservations/items', to: 'reservations/items#update', as: :update_items
  get "klubowicze/:kw_id" => 'users#show', as: :user
  get "klubowicze" => 'users#index', as: :users

  get '/', to: 'activities/mountain_routes#index',
    constraints: lambda { |req| req.env['SERVER_NAME'].match('przejscia') }

  get 'zarezerwuj' => 'reservations#new', as: :reserve
  get 'zgloszenie' => 'profiles#new'
  get 'application' => 'profiles#new', locale: :en

  get 'pages/home' => 'pages#show', id: 'home'
  get 'pages/rules' => 'pages#show', id: 'rules'
  get "pages/*id" => 'pages#show', as: :page, format: false
  get 'admin/dostepy' => 'pages#show', id: 'roles'
  get 'trening/skimo' => 'pages#show', id: 'skimo'

  get '/up', to: 'health_check#show'
  root to: 'pages#show', id: 'home'
end
