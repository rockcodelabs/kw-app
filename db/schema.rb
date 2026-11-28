# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2026_11_28_130100) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "activities_competitions", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.date "start_date"
    t.date "end_date"
    t.string "website"
    t.integer "creator_id"
    t.integer "country", null: false
    t.integer "category_type"
    t.string "slug", null: false
    t.string "state", default: "draft", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "bold", default: false, null: false
    t.integer "series"
  end

  create_table "activities_contracts", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.integer "score", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "activities_route_contracts", force: :cascade do |t|
    t.integer "route_id", null: false
    t.integer "contract_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "business_course_conversations", force: :cascade do |t|
    t.integer "course_id", null: false
    t.integer "conversation_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["course_id", "conversation_id"], name: "business_course_conversations_uniq", unique: true
  end

  create_table "business_course_package_types", force: :cascade do |t|
    t.string "name", null: false
    t.integer "business_course_record_id", null: false
    t.integer "cost", null: false
    t.boolean "increase_limit", default: false, null: false
    t.boolean "membership", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "business_course_types", force: :cascade do |t|
    t.string "name", null: false
    t.string "sign_ups_uri", null: false
    t.integer "logo_type", default: 0, null: false
    t.string "type_sym", null: false
  end

  create_table "business_courses", force: :cascade do |t|
    t.datetime "starts_at"
    t.datetime "ends_at"
    t.text "description"
    t.integer "seats", default: 0, null: false
    t.integer "creator_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "slug", null: false
    t.string "state", default: "draft", null: false
    t.string "instructor"
    t.integer "instructor_id"
    t.integer "price"
    t.integer "max_seats"
    t.string "sign_up_url"
    t.integer "coordinator_id"
    t.integer "event_id"
    t.integer "payment_first_cost", default: 0, null: false
    t.integer "payment_second_cost", default: 0, null: false
    t.text "email_first_content"
    t.text "email_second_content"
    t.text "equipment"
    t.boolean "cash", default: false, null: false
    t.string "sa_title"
    t.boolean "packages", default: false, null: false
    t.integer "course_type_id"
    t.index ["slug"], name: "index_business_courses_on_slug", unique: true
  end

  create_table "business_instructors", force: :cascade do |t|
    t.string "name"
    t.integer "kw_id"
    t.boolean "active", default: true, null: false
    t.string "description"
    t.string "attachements"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "business_list_courses", force: :cascade do |t|
    t.integer "course_id", null: false
    t.integer "list_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["course_id", "list_id"], name: "index_business_list_courses_on_course_id_and_list_id", unique: true
  end

  create_table "business_lists", force: :cascade do |t|
    t.text "description"
    t.integer "sign_up_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "birthdate"
    t.string "birthplace"
    t.string "alternative_email"
  end

  create_table "business_sign_ups", force: :cascade do |t|
    t.integer "user_id"
    t.integer "course_id"
    t.string "name"
    t.string "email"
    t.string "code", default: "e25902af54d1a5c8", null: false
    t.datetime "expired_at"
    t.datetime "sent_at"
    t.integer "admin_id"
    t.string "question"
    t.integer "send_user_id"
    t.datetime "paid_email_sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "phone", null: false
    t.date "birthdate"
    t.string "birthplace"
    t.string "alternative_email"
    t.string "state", default: "new", null: false
    t.datetime "equipment_at"
    t.integer "business_course_package_type_id"
  end

  create_table "case_presences", force: :cascade do |t|
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "accepted_terms", default: false, null: false
    t.date "presence_date", null: false
    t.integer "cerber_id"
    t.index ["user_id", "presence_date"], name: "index_case_presences_on_user_id_and_presence_date", unique: true
  end

  create_table "club_meetings_ideas", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.bigint "user_id", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_club_meetings_ideas_on_name", unique: true
    t.index ["slug"], name: "index_club_meetings_ideas_on_slug", unique: true
    t.index ["user_id"], name: "index_club_meetings_ideas_on_user_id"
  end

  create_table "comments", force: :cascade do |t|
    t.string "commentable_type", null: false
    t.integer "commentable_id", null: false
    t.integer "user_id", null: false
    t.text "body"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "competition_package_types", id: :serial, force: :cascade do |t|
    t.string "name", null: false
    t.integer "competition_record_id", null: false
    t.integer "cost", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "membership", default: false, null: false
    t.integer "junior_year"
  end

  create_table "competitions", id: :serial, force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "edition_sym", null: false
    t.boolean "single", default: false, null: false
    t.boolean "team_name", default: false, null: false
    t.string "baner"
    t.string "rules"
    t.boolean "closed", default: false, null: false
    t.integer "limit", default: 0, null: false
    t.text "email_text", null: false
    t.boolean "matrimonial_office", default: false, null: false
    t.string "tshirt_url"
    t.string "organizer_email", default: "kw@kw.krakow.pl", null: false
    t.datetime "event_date"
    t.text "alert"
    t.boolean "accept_first", default: false, null: false
    t.datetime "close_payment"
    t.boolean "license_id_required", default: false, null: false
    t.boolean "country_required", default: false, null: false
    t.text "medical_rules_text"
    t.text "rules_text"
    t.datetime "sign_up_starts_at"
    t.boolean "weekend_nights", default: false, null: false
    t.text "weekend_nights_text"
    t.text "en_email_text"
    t.string "custom_form"
    t.text "info_above_sign_ups"
    t.string "results_url"
  end

  create_table "competiton_photo_sets", id: :serial, force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "contract_events", force: :cascade do |t|
    t.integer "event_id", null: false
    t.integer "contract_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "contract_templates", force: :cascade do |t|
    t.string "name"
    t.string "group_type"
    t.string "payout_type"
    t.string "financial_type"
    t.string "document_type"
    t.string "event_type"
    t.string "substantive_type"
    t.string "area_type"
    t.string "activity_type"
    t.integer "checker_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "project_id"
    t.boolean "project", default: false, null: false
    t.text "description"
  end

  create_table "contract_users", force: :cascade do |t|
    t.integer "contract_id", null: false
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "contractors", force: :cascade do |t|
    t.string "name"
    t.string "nip"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "email"
    t.string "www"
    t.string "contact_name"
    t.integer "reason_type", default: 0, null: false
    t.string "phone"
    t.string "logo"
    t.integer "profession_type", default: 0, null: false
  end

  create_table "contracts", force: :cascade do |t|
    t.string "title"
    t.string "state", default: "new", null: false
    t.integer "creator_id", null: false
    t.text "description"
    t.float "cost"
    t.integer "acceptor_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "attachments"
    t.integer "document_type"
    t.date "document_date"
    t.integer "group_type"
    t.integer "financial_type"
    t.date "period_date"
    t.integer "contractor_id"
    t.integer "event_id"
    t.integer "substantive_type"
    t.integer "payout_type"
    t.datetime "preclosed_date"
    t.string "document_number"
    t.integer "internal_number"
    t.integer "preacceptor_id"
    t.integer "event_type"
    t.integer "area_type"
    t.integer "activity_type"
    t.integer "checker_id"
    t.integer "contract_template_id"
    t.integer "closer_id"
    t.integer "currency_type", default: 0, null: false
    t.string "bank_account"
    t.string "bank_account_owner"
    t.boolean "document_deliver", default: false, null: false
    t.boolean "accountant_deliver", default: false, null: false
    t.datetime "closed_at"
    t.index ["internal_number", "period_date"], name: "index_contracts_on_internal_number_and_period_date", unique: true
  end

  create_table "donations", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.integer "cost"
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "display_name"
    t.integer "action_type"
    t.index ["user_id"], name: "index_donations_on_user_id"
  end

  create_table "edition_categories", id: :serial, force: :cascade do |t|
    t.integer "edition_record_id", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "mandatory_fields", default: [], array: true
  end

  create_table "emails", force: :cascade do |t|
    t.string "message_id", null: false
    t.datetime "delivered_at"
    t.integer "mailable_id", null: false
    t.string "mailable_type", null: false
    t.string "state", default: "sent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "events", id: :serial, force: :cascade do |t|
    t.string "name"
    t.string "place"
    t.datetime "event_date"
    t.integer "manager_kw_id"
    t.string "participants"
    t.string "application_list_url"
    t.integer "price_for_members"
    t.integer "price_for_non_members"
    t.date "application_date"
    t.date "payment_date"
    t.string "account_number"
    t.string "event_rules_url"
    t.string "google_group_discussion_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description"
  end

  create_table "events_sign_ups", id: :serial, force: :cascade do |t|
    t.text "remarks"
    t.integer "competition_record_id", null: false
    t.string "participant_name_1"
    t.string "participant_name_2"
    t.string "participant_email_1"
    t.string "participant_email_2"
    t.string "participant_birth_year_1"
    t.string "participant_birth_year_2"
    t.string "participant_city_1"
    t.string "participant_city_2"
    t.string "participant_team_1"
    t.string "participant_team_2"
    t.string "participant_gender_1"
    t.string "participant_gender_2"
    t.integer "competition_package_type_1_id", null: false
    t.integer "competition_package_type_2_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "single", default: false, null: false
    t.integer "participant_kw_id_1"
    t.integer "participant_kw_id_2"
    t.string "team_name"
    t.string "participant_phone_1"
    t.string "participant_phone_2"
    t.integer "teammate_id"
    t.string "tshirt_size_1"
    t.string "tshirt_size_2"
    t.datetime "sent_at"
    t.datetime "expired_at"
    t.integer "participant_license_id_1"
    t.integer "participant_license_id_2"
    t.integer "participant_country_2"
    t.integer "participant_country_1"
    t.boolean "rescuer", default: false, null: false
    t.boolean "friday_night", default: false, null: false
    t.boolean "saturday_night", default: false, null: false
    t.integer "license_number"
    t.string "participant_first_name_1"
    t.integer "start_number"
  end

  create_table "friendly_id_slugs", force: :cascade do |t|
    t.string "slug", null: false
    t.integer "sluggable_id", null: false
    t.string "sluggable_type", limit: 50
    t.string "scope"
    t.datetime "created_at"
    t.index ["slug", "sluggable_type", "scope"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope", unique: true
    t.index ["slug", "sluggable_type"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type"
    t.index ["sluggable_type", "sluggable_id"], name: "index_friendly_id_slugs_on_sluggable_type_and_sluggable_id"
  end

  create_table "hearts", id: :serial, force: :cascade do |t|
    t.integer "mountain_route_id"
    t.integer "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["mountain_route_id"], name: "index_hearts_on_mountain_route_id"
    t.index ["user_id"], name: "index_hearts_on_user_id"
  end

  create_table "items", id: :serial, force: :cascade do |t|
    t.string "display_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description"
    t.boolean "rentable", default: false
    t.integer "owner", default: 0
    t.integer "cost", default: 0
    t.integer "rentable_id"
  end

  create_table "library_authors", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "library_inventories", force: :cascade do |t|
    t.string "name", null: false
    t.integer "state", default: 0, null: false
    t.datetime "started_at", null: false
    t.datetime "closed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["state"], name: "index_library_inventories_one_open", unique: true, where: "(state = 0)"
  end

  create_table "library_inventory_checks", force: :cascade do |t|
    t.bigint "inventory_id", null: false
    t.bigint "item_id", null: false
    t.datetime "checked_at", null: false
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["inventory_id", "item_id"], name: "index_library_inventory_checks_on_inventory_and_item", unique: true
    t.index ["inventory_id"], name: "index_library_inventory_checks_on_inventory_id"
    t.index ["item_id"], name: "index_library_inventory_checks_on_item_id"
  end

  create_table "library_item_authors", force: :cascade do |t|
    t.integer "item_id"
    t.integer "author_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["item_id", "author_id"], name: "index_library_item_authors_on_item_id_and_author_id", unique: true
  end

  create_table "library_item_reservations", force: :cascade do |t|
    t.integer "item_id", null: false
    t.integer "user_id", null: false
    t.date "returned_at"
    t.date "received_at", null: false
    t.integer "caution"
    t.text "description"
    t.date "back_at"
    t.integer "back_by"
  end

  create_table "library_item_scans", force: :cascade do |t|
    t.bigint "item_id", null: false
    t.integer "kind", default: 3, null: false
    t.integer "position", default: 0, null: false
    t.string "image", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["item_id", "position"], name: "index_library_item_scans_on_item_and_position"
    t.index ["item_id"], name: "index_library_item_scans_on_item_id"
    t.index ["item_id"], name: "index_library_item_scans_one_cover_per_item", unique: true, where: "(kind = 0)"
  end

  create_table "library_item_tags", force: :cascade do |t|
    t.integer "item_id"
    t.integer "tag_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "library_items", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.string "attachments"
    t.integer "area_id"
    t.integer "doc_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "item_id"
    t.boolean "reading_room", default: false, null: false
    t.string "autors"
    t.date "publishment_at"
    t.string "number"
    t.string "slug", null: false
    t.string "original_title"
    t.string "edition_info"
    t.string "publisher"
    t.text "disciplines", default: [], null: false, array: true
    t.text "countries", default: [], null: false, array: true
    t.string "region"
    t.datetime "label_printed_at"
  end

  create_table "library_tags", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "parent_id"
    t.integer "type"
  end

  create_table "likes", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "likeable_type", null: false
    t.bigint "likeable_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["likeable_type", "likeable_id"], name: "index_likes_on_likeable_type_and_likeable_id"
    t.index ["user_id", "likeable_type", "likeable_id"], name: "index_likes_on_user_id_and_likeable_type_and_likeable_id", unique: true
    t.index ["user_id"], name: "index_likes_on_user_id"
  end

  create_table "mailboxer_conversation_opt_outs", id: :serial, force: :cascade do |t|
    t.string "unsubscriber_type"
    t.integer "unsubscriber_id"
    t.integer "conversation_id"
    t.index ["conversation_id"], name: "index_mailboxer_conversation_opt_outs_on_conversation_id"
    t.index ["unsubscriber_id", "unsubscriber_type"], name: "index_mailboxer_conversation_opt_outs_on_unsubscriber_id_type"
  end

  create_table "mailboxer_conversations", id: :serial, force: :cascade do |t|
    t.string "subject", default: ""
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "code", default: "a4cae3e24c9b78a1", null: false
  end

  create_table "mailboxer_notifications", id: :serial, force: :cascade do |t|
    t.string "type"
    t.text "body"
    t.string "subject", default: ""
    t.string "sender_type"
    t.integer "sender_id"
    t.integer "conversation_id"
    t.boolean "draft", default: false
    t.string "notification_code"
    t.string "notified_object_type"
    t.integer "notified_object_id"
    t.string "attachment"
    t.datetime "updated_at", null: false
    t.datetime "created_at", null: false
    t.boolean "global", default: false
    t.datetime "expires"
    t.index ["conversation_id"], name: "index_mailboxer_notifications_on_conversation_id"
    t.index ["notified_object_id", "notified_object_type"], name: "index_mailboxer_notifications_on_notified_object_id_and_type"
    t.index ["notified_object_type", "notified_object_id"], name: "mailboxer_notifications_notified_object"
    t.index ["sender_id", "sender_type"], name: "index_mailboxer_notifications_on_sender_id_and_sender_type"
    t.index ["type"], name: "index_mailboxer_notifications_on_type"
  end

  create_table "mailboxer_receipts", id: :serial, force: :cascade do |t|
    t.string "receiver_type"
    t.integer "receiver_id"
    t.integer "notification_id", null: false
    t.boolean "is_read", default: false
    t.boolean "trashed", default: false
    t.boolean "deleted", default: false
    t.string "mailbox_type", limit: 25
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_delivered", default: false
    t.string "delivery_method"
    t.string "message_id"
    t.index ["notification_id"], name: "index_mailboxer_receipts_on_notification_id"
    t.index ["receiver_id", "receiver_type"], name: "index_mailboxer_receipts_on_receiver_id_and_receiver_type"
  end

  create_table "management_cases", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.string "state", default: "draft", null: false
    t.text "destrciption"
    t.integer "creator_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "attachments"
    t.string "number"
    t.boolean "hidden", default: false, null: false
    t.string "doc_url"
    t.boolean "hide_votes", default: false, null: false
    t.datetime "acceptance_date"
    t.string "who_ids", array: true
    t.integer "voting_type", default: 0, null: false
    t.integer "meeting_type", default: 0, null: false
    t.boolean "public", default: false, null: false
    t.integer "position"
    t.string "final_voting_result"
    t.index ["slug"], name: "index_management_cases_on_slug", unique: true
  end

  create_table "management_commissions", force: :cascade do |t|
    t.integer "owner_id", null: false
    t.integer "authorized_id", null: false
    t.boolean "approval", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_id"], name: "index_management_commissions_on_owner_id", unique: true
  end

  create_table "management_informations", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "url"
    t.integer "news_type", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "group_type", default: 0, null: false
    t.boolean "starred", default: false, null: false
    t.boolean "web", default: false, null: false
    t.string "slug"
    t.string "attachments"
  end

  create_table "management_resolutions", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "slug", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "state", default: "draft", null: false
    t.string "number", null: false
    t.date "passed_date"
  end

  create_table "management_vote_users", force: :cascade do |t|
    t.integer "user_id"
    t.integer "vote_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "management_votes", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "case_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "decision", default: "approved", null: false
    t.boolean "commission", default: false, null: false
    t.integer "authorized_id"
    t.index ["user_id", "case_id"], name: "index_management_votes_on_user_id_and_case_id", unique: true
  end

  create_table "marketing_discounts", force: :cascade do |t|
    t.string "logo"
    t.integer "contractor_id", null: false
    t.integer "user_id"
    t.string "description"
    t.string "attachments"
    t.integer "amount"
    t.integer "amount_type"
    t.string "link"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "slug"
    t.integer "category_type"
    t.string "amount_body"
    t.string "amount_text"
  end

  create_table "marketing_sponsorship_requests", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "contractor_id", null: false
    t.string "description"
    t.string "attachments"
    t.string "state", default: "draft", null: false
    t.datetime "sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "doc_url"
  end

  create_table "membership_fees", id: :serial, force: :cascade do |t|
    t.string "year"
    t.integer "cost", default: 100, null: false
    t.integer "kw_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "creator_id"
    t.boolean "plastic", default: false, null: false
    t.index ["kw_id"], name: "index_membership_fees_on_kw_id"
  end

  create_table "messaging_conversation_items", force: :cascade do |t|
    t.integer "conversation_id", null: false
    t.string "messageable_type", null: false
    t.integer "messageable_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id"], name: "index_messaging_conversation_items_on_conversation_id"
    t.index ["messageable_type", "messageable_id"], name: "messageable_conversations"
  end

  create_table "meteoblue_records", force: :cascade do |t|
    t.date "time", null: false
    t.integer "pictocode"
    t.float "temperature_max"
    t.float "temperature_min"
    t.float "temperature_mean"
    t.float "felttemperature_max"
    t.float "felttemperature_min"
    t.integer "winddirection"
    t.integer "precipitation_probability"
    t.string "rainspot"
    t.integer "predictability_class"
    t.integer "predictability"
    t.float "precipitation"
    t.float "snowfraction"
    t.integer "sealevelpressure_max"
    t.integer "sealevelpressure_min"
    t.integer "sealevelpressure_mean"
    t.float "windspeed_max"
    t.float "windspeed_mean"
    t.float "windspeed_min"
    t.integer "relativehumidity_max"
    t.integer "relativehumidity_min"
    t.integer "relativehumidity_mean"
    t.float "convective_precipitation"
    t.float "precipitation_hours"
    t.float "humiditygreater90_hours"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "meteogram"
    t.string "location"
    t.index ["time"], name: "index_meteoblue_records_on_time", unique: true
  end

  create_table "mountain_route_points", force: :cascade do |t|
    t.text "description"
    t.decimal "lat", precision: 10, scale: 6, null: false
    t.decimal "lng", precision: 10, scale: 6, null: false
    t.integer "mountain_route_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "mountain_routes", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.string "name"
    t.text "description"
    t.string "difficulty"
    t.string "partners"
    t.integer "rating"
    t.date "climbing_date"
    t.string "peak"
    t.string "time"
    t.integer "route_type", default: 0
    t.string "area"
    t.integer "length"
    t.string "mountains"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "hidden", default: false, null: false
    t.string "attachments"
    t.integer "hearts_count", default: 0
    t.boolean "training", default: false, null: false
    t.string "slug"
    t.string "gps_tracks"
    t.integer "boar_length", default: 0
    t.string "photograph"
    t.string "strava_id"
    t.string "map_summary_polyline"
    t.float "distance"
    t.integer "kurtyka_difficulty"
    t.integer "climb_style"
    t.index ["climbing_date"], name: "index_mountain_routes_on_climbing_date", order: :desc
    t.index ["slug"], name: "index_mountain_routes_on_slug", unique: true
    t.index ["user_id"], name: "index_mountain_routes_on_user_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.integer "recipient_id"
    t.integer "actor_id"
    t.datetime "read_at"
    t.string "action"
    t.integer "notifiable_id", null: false
    t.string "notifiable_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "participants", id: :serial, force: :cascade do |t|
    t.string "full_name"
    t.string "email", null: false
    t.string "phone"
    t.string "prefered_time", default: [], array: true
    t.text "equipment", default: [], array: true
    t.string "height"
    t.text "recommended_by", default: [], array: true
    t.integer "kw_id"
    t.integer "course_id", null: false
    t.date "birth_date"
    t.string "birth_place"
    t.string "pre_cost"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "payments", id: :serial, force: :cascade do |t|
    t.boolean "cash", default: false
    t.string "dotpay_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "state", default: "unpaid"
    t.string "payable_type"
    t.integer "payable_id"
    t.string "payment_url"
    t.integer "cash_user_id"
    t.boolean "deleted", default: false, null: false
    t.datetime "refunded_at"
    t.integer "amount"
  end

  create_table "photo_competitions", id: :serial, force: :cascade do |t|
    t.string "name", null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "closed", default: false, null: false
    t.datetime "start_voting_date"
    t.datetime "end_voting_date"
  end

  create_table "photo_requests", id: :serial, force: :cascade do |t|
    t.integer "edition_record_id", null: false
    t.integer "user_id", null: false
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "file"
    t.integer "category_record_id", null: false
    t.string "area"
    t.string "title"
    t.string "original_filename"
    t.integer "likes_count", default: 0, null: false
    t.boolean "accepted", default: false, null: false
  end

  create_table "photos", id: :serial, force: :cascade do |t|
    t.string "file_filename"
    t.integer "file_size"
    t.string "file_content_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "product_fields", id: :serial, force: :cascade do |t|
    t.string "name"
    t.string "field_type"
    t.boolean "required"
    t.integer "product_type_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_type_id"], name: "index_product_fields_on_product_type_id"
  end

  create_table "product_types", id: :serial, force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "products", id: :serial, force: :cascade do |t|
    t.string "name"
    t.text "description"
  end

  create_table "profile_lists", force: :cascade do |t|
    t.text "description"
    t.integer "section_type", null: false
    t.integer "acceptor_id"
    t.boolean "accepted", default: false, null: false
    t.integer "profile_id", null: false
    t.string "attachments"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "profiles", id: :serial, force: :cascade do |t|
    t.integer "kw_id"
    t.date "birth_date"
    t.string "birth_place"
    t.string "pesel"
    t.string "city"
    t.string "postal_code"
    t.string "main_address"
    t.string "optional_address"
    t.text "recommended_by", default: [], array: true
    t.boolean "main_discussion_group", default: false
    t.text "sections", default: [], array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "accepted", default: false
    t.string "first_name"
    t.string "last_name"
    t.string "email"
    t.string "phone"
    t.text "acomplished_courses", default: [], array: true
    t.string "profession"
    t.date "application_date"
    t.boolean "added", default: false
    t.text "position", default: [], array: true
    t.date "date_of_death"
    t.text "remarks"
    t.integer "cost"
    t.integer "acceptor_id"
    t.boolean "plastic", default: false, null: false
    t.datetime "sent_at"
    t.datetime "accepted_at"
    t.string "photo"
    t.string "locale", default: "pl", null: false
    t.integer "gender"
    t.string "course_cert"
    t.index ["kw_id"], name: "index_profiles_on_kw_id", unique: true
  end

  create_table "project_users", force: :cascade do |t|
    t.integer "project_id", null: false
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "user_id"], name: "index_project_users_on_project_id_and_user_id", unique: true
  end

  create_table "projects", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.integer "coordinator_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "needed_knowledge"
    t.text "benefits"
    t.text "estimated_time"
    t.string "attachments"
    t.text "know_how"
    t.string "state", default: "draft"
    t.string "slug"
    t.integer "group_type", default: 0, null: false
    t.index ["slug"], name: "index_projects_on_slug", unique: true
  end

  create_table "reservation_items", id: :serial, force: :cascade do |t|
    t.integer "item_id"
    t.integer "reservation_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "reservations", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.string "state", default: "reserved"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "start_date"
    t.date "end_date"
    t.text "remarks"
    t.boolean "canceled", default: false
    t.string "photos"
  end

  create_table "roles", force: :cascade do |t|
    t.string "name"
    t.string "resource_type"
    t.bigint "resource_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name", "resource_type", "resource_id"], name: "index_roles_on_name_and_resource_type_and_resource_id"
    t.index ["resource_type", "resource_id"], name: "index_roles_on_resource_type_and_resource_id"
  end

  create_table "route_colleagues", id: :serial, force: :cascade do |t|
    t.integer "colleague_id"
    t.integer "mountain_route_id"
    t.index ["colleague_id", "mountain_route_id"], name: "index_route_colleagues_on_colleague_id_and_mountain_route_id", unique: true
  end

  create_table "sale_announcements", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "user_id"
    t.text "description"
    t.float "price"
    t.boolean "archived", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sale_announcements_on_user_id"
  end

  create_table "settings", force: :cascade do |t|
    t.string "name", null: false
    t.text "content"
    t.string "back_url"
    t.integer "content_type", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "path"
  end

  create_table "settlement_incomes", force: :cascade do |t|
    t.string "name"
    t.string "description"
    t.float "cost"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "settlement_project_items", force: :cascade do |t|
    t.string "accountable_type", null: false
    t.integer "accountable_id", null: false
    t.integer "project_id"
    t.integer "user_id"
    t.float "cost"
    t.index ["accountable_id", "project_id"], name: "index_settlement_project_items_on_accountable_id_and_project_id", unique: true
    t.index ["user_id"], name: "index_settlement_project_items_on_user_id"
  end

  create_table "settlement_projects", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "state", default: "open", null: false
    t.integer "area_type", default: 0, null: false
  end

  create_table "shmu_diagrams", force: :cascade do |t|
    t.datetime "diagram_time"
    t.string "place"
    t.string "image"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "shop_item_kinds", force: :cascade do |t|
    t.string "name"
    t.integer "quantity", default: 1, null: false
    t.integer "item_id", null: false
    t.float "price"
  end

  create_table "shop_items", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.string "slug", null: false
    t.string "state", default: "draft", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "shop_order_items", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "order_id", null: false
    t.integer "item_id", null: false
    t.integer "quantity", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "item_kind_id", null: false
  end

  create_table "shop_orders", force: :cascade do |t|
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "state", default: "new", null: false
  end

  create_table "snw_applies", force: :cascade do |t|
    t.integer "kw_id", null: false
    t.string "cv", null: false
    t.string "skills"
    t.string "courses"
    t.boolean "avalanche", default: false, null: false
    t.date "avalanche_date"
    t.boolean "first_aid", default: false, null: false
    t.string "attachments"
    t.string "state", default: "new", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "snw_profiles", id: :serial, force: :cascade do |t|
    t.string "question_1"
    t.integer "question_2"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "storage_uploads", force: :cascade do |t|
    t.string "file", null: false
    t.integer "uploadable_id", null: false
    t.string "uploadable_type", null: false
    t.integer "user_id"
    t.string "content_type"
    t.string "file_size"
    t.datetime "created_at", default: -> { "now()" }, null: false
    t.datetime "updated_at", default: -> { "now()" }, null: false
    t.index ["uploadable_id", "uploadable_type"], name: "index_storage_uploads_on_uploadable_id_and_uploadable_type"
    t.index ["user_id"], name: "index_storage_uploads_on_user_id"
  end

  create_table "strzelecki_sign_ups", id: :serial, force: :cascade do |t|
    t.string "name_1"
    t.string "email_1"
    t.boolean "single", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "organization_1"
    t.boolean "vege_1", default: false
    t.integer "birth_year_1"
    t.integer "gender_1", default: 0
    t.integer "package_type_1", default: 0
    t.text "remarks"
    t.string "name_2"
    t.string "birth_year_2"
    t.boolean "vege_2", default: false
    t.string "email_2"
    t.string "organization_2"
    t.string "city_1"
    t.string "city_2"
    t.integer "package_type_2", default: 0
    t.string "phone_1"
    t.string "phone_2"
    t.integer "gender_2"
    t.integer "tshirt_size_1"
    t.integer "tshirt_size_2"
  end

  create_table "supplementary_course_package_types", id: :serial, force: :cascade do |t|
    t.string "name", null: false
    t.integer "supplementary_course_record_id", null: false
    t.integer "cost", null: false
    t.boolean "increase_limit", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "membership", default: false, null: false
  end

  create_table "supplementary_courses", id: :serial, force: :cascade do |t|
    t.string "name"
    t.string "place"
    t.datetime "start_date"
    t.datetime "end_date"
    t.integer "organizator_id"
    t.text "participants", default: [], array: true
    t.integer "price_kw"
    t.integer "price_non_kw"
    t.datetime "application_date"
    t.boolean "accepted", default: false
    t.text "remarks"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "category", default: 0, null: false
    t.boolean "price", default: false, null: false
    t.integer "limit", default: 0, null: false
    t.boolean "one_day", default: true, null: false
    t.boolean "active", default: false, null: false
    t.boolean "open", default: true, null: false
    t.boolean "last_fee_paid", default: false, null: false
    t.string "email"
    t.boolean "cash", default: false, null: false
    t.string "baner"
    t.boolean "packages", default: false
    t.string "slug", null: false
    t.integer "kind", default: 0, null: false
    t.integer "payment_type", default: 0, null: false
    t.integer "expired_hours", default: 0, null: false
    t.boolean "reserve_list", default: false, null: false
    t.integer "baner_type", default: 0, null: false
    t.text "email_remarks"
    t.integer "state", default: 0, null: false
    t.boolean "question", default: false, null: false
    t.boolean "send_manually", default: false, null: false
    t.text "paid_email"
    t.datetime "end_application_date"
    t.datetime "conversation_at"
    t.index ["slug"], name: "index_supplementary_courses_on_slug", unique: true
  end

  create_table "supplementary_sign_ups", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.integer "course_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.string "email"
    t.string "code", default: "aabe7e693a125b4b", null: false
    t.integer "supplementary_course_package_type_id"
    t.datetime "expired_at"
    t.datetime "sent_at"
    t.integer "admin_id"
    t.string "question"
    t.integer "sent_user_id"
    t.datetime "paid_email_sent_at"
    t.index ["course_id", "user_id"], name: "index_supplementary_sign_ups_on_course_id_and_user_id", unique: true
  end

  create_table "topr_records", force: :cascade do |t|
    t.date "time"
    t.text "statement"
    t.integer "avalanche_degree"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "topr_pdf"
    t.string "topr_degree"
  end

  create_table "training_exercises", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.integer "group_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "training_user_contracts", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "route_id", null: false
    t.integer "contract_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "route_id", "contract_id"], name: "user_route_contract_unique", unique: true
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.integer "kw_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.inet "current_sign_in_ip"
    t.inet "last_sign_in_ip"
    t.boolean "admin", default: false, null: false
    t.integer "warnings", default: 0
    t.string "phone"
    t.boolean "curator", default: false, null: false
    t.string "refresh_token"
    t.string "access_token"
    t.text "roles", default: [], array: true
    t.string "avatar"
    t.boolean "hide", default: false
    t.boolean "boars", default: true, null: false
    t.boolean "ski_hater", default: false, null: false
    t.string "slug"
    t.boolean "climbing_boars", default: true, null: false
    t.text "description"
    t.integer "author_number"
    t.string "facebook_url"
    t.string "instagram_url"
    t.string "website_url"
    t.boolean "snw_blog", default: false, null: false
    t.string "snw_groups", default: [], array: true
    t.integer "gender"
    t.string "strava_access_token"
    t.string "strava_refresh_token"
    t.string "strava_client_id"
    t.string "strava_client_secret"
    t.datetime "strava_expires_at"
    t.boolean "strava_subscribe", default: false, null: false
    t.string "strava_athlete_id"
    t.string "strava_subscription_id"
    t.boolean "ski", default: true, null: false
    t.boolean "regular_climbing", default: true, null: false
    t.boolean "trad_climbing", default: false, null: false
    t.boolean "sport_climbing", default: false, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["slug"], name: "index_users_on_slug", unique: true
  end

  create_table "users_roles", id: false, force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "role_id"
    t.index ["role_id"], name: "index_users_roles_on_role_id"
    t.index ["user_id", "role_id"], name: "index_users_roles_on_user_id_and_role_id"
    t.index ["user_id"], name: "index_users_roles_on_user_id"
  end

  create_table "versions", force: :cascade do |t|
    t.string "item_type", null: false
    t.bigint "item_id", null: false
    t.string "event", null: false
    t.string "whodunnit"
    t.text "object"
    t.datetime "created_at"
    t.text "object_changes"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  create_table "weather_records", force: :cascade do |t|
    t.string "place"
    t.float "temp"
    t.float "daily_snow"
    t.float "all_snow"
    t.integer "snow_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "wind_value"
    t.integer "wind_direction"
    t.integer "cloud"
    t.string "cloud_url"
    t.string "snow_type_text"
    t.string "snow_surface"
  end

  create_table "yearly_prize_categories", force: :cascade do |t|
    t.bigint "yearly_prize_edition_id", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["yearly_prize_edition_id"], name: "index_yearly_prize_categories_on_yearly_prize_edition_id"
  end

  create_table "yearly_prize_editions", force: :cascade do |t|
    t.integer "year", null: false
    t.string "name", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "closed", default: false, null: false
    t.boolean "votable", default: false, null: false
    t.datetime "start_voting_date"
    t.datetime "end_voting_date"
  end

  create_table "yearly_prize_request_users", force: :cascade do |t|
    t.bigint "yearly_prize_request_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_yearly_prize_request_users_on_user_id"
    t.index ["yearly_prize_request_id"], name: "index_yearly_prize_request_users_on_yearly_prize_request_id"
  end

  create_table "yearly_prize_requests", force: :cascade do |t|
    t.bigint "yearly_prize_edition_id", null: false
    t.text "author_description"
    t.integer "author_id", null: false
    t.text "prize_jury_description"
    t.integer "likes_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "yearly_prize_category_id", null: false
    t.string "attachments"
    t.boolean "accepted", default: false
    t.index ["author_id"], name: "index_yearly_prize_requests_on_author_id"
    t.index ["yearly_prize_category_id"], name: "index_yearly_prize_requests_on_yearly_prize_category_id"
    t.index ["yearly_prize_edition_id"], name: "index_yearly_prize_requests_on_yearly_prize_edition_id"
  end

  add_foreign_key "club_meetings_ideas", "users"
  add_foreign_key "library_inventory_checks", "library_inventories", column: "inventory_id"
  add_foreign_key "library_inventory_checks", "library_items", column: "item_id"
  add_foreign_key "library_item_scans", "library_items", column: "item_id"
  add_foreign_key "likes", "users"
  add_foreign_key "mailboxer_conversation_opt_outs", "mailboxer_conversations", column: "conversation_id", name: "mb_opt_outs_on_conversations_id"
  add_foreign_key "mailboxer_notifications", "mailboxer_conversations", column: "conversation_id", name: "notifications_on_conversation_id"
  add_foreign_key "mailboxer_receipts", "mailboxer_notifications", column: "notification_id", name: "receipts_on_notification_id"
  add_foreign_key "product_fields", "product_types"
  add_foreign_key "sale_announcements", "users"
  add_foreign_key "yearly_prize_categories", "yearly_prize_editions"
  add_foreign_key "yearly_prize_request_users", "users"
  add_foreign_key "yearly_prize_request_users", "yearly_prize_requests"
  add_foreign_key "yearly_prize_requests", "yearly_prize_editions"
end
