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

ActiveRecord::Schema.define(version: 2022_02_06_235231) do

  create_table "addons", charset: "latin1", force: :cascade do |t|
    t.string "name"
    t.string "category"
    t.text "obj"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["name"], name: "index_addons_on_name", unique: true
  end

  create_table "collaborators", charset: "latin1", force: :cascade do |t|
    t.bigint "website_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.text "permissions", size: :medium
    t.index ["website_id", "user_id"], name: "index_collaborators_on_website_id_and_user_id", unique: true
    t.index ["website_id"], name: "index_collaborators_on_website_id"
  end

  create_table "coupons", charset: "latin1", force: :cascade do |t|
    t.string "str_id"
    t.float "extra_ratio_rebate"
    t.integer "nb_days_valid"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["str_id"], name: "index_coupons_on_str_id", unique: true
  end

  create_table "credit_action_loops", charset: "latin1", force: :cascade do |t|
    t.string "type"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["type"], name: "index_credit_action_loops_on_type"
  end

  create_table "credit_actions", charset: "latin1", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "website_id", null: false
    t.string "action_type"
    t.float "credits_spent"
    t.float "credits_remaining"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "credit_action_loop_id"
    t.bigint "subscription_id"
    t.index ["credit_action_loop_id"], name: "index_credit_actions_on_credit_action_loop_id"
    t.index ["subscription_id"], name: "index_credit_actions_on_subscription_id"
    t.index ["user_id"], name: "index_credit_actions_on_user_id"
    t.index ["website_id"], name: "index_credit_actions_on_website_id"
  end

  create_table "executions", charset: "latin1", force: :cascade do |t|
    t.bigint "website_id"
    t.bigint "website_location_id"
    t.string "status"
    t.text "result", size: :medium
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "type", default: "Deployment"
    t.text "events", size: :medium
    t.text "obj", size: :medium
    t.bigint "parent_execution_id"
    t.index ["parent_execution_id"], name: "index_executions_on_parent_execution_id"
    t.index ["website_id"], name: "index_executions_on_website_id"
    t.index ["website_location_id"], name: "index_executions_on_website_location_id"
  end

  create_table "friend_invites", charset: "latin1", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "order_id"
    t.string "status"
    t.string "email"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "created_by_ip", default: ""
    t.index ["email"], name: "index_friend_invites_on_email", unique: true
    t.index ["user_id"], name: "index_friend_invites_on_user_id"
  end

  create_table "global_storages", charset: "latin1", force: :cascade do |t|
    t.string "type"
    t.text "obj"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "key", default: ""
    t.index ["key"], name: "index_global_storages_on_key"
  end

  create_table "histories", charset: "latin1", force: :cascade do |t|
    t.integer "ref_id"
    t.string "type"
    t.text "obj", size: :medium
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["type", "ref_id"], name: "index_histories_on_type_and_ref_id"
    t.index ["type"], name: "index_histories_on_type"
  end

  create_table "location_servers", charset: "latin1", force: :cascade do |t|
    t.bigint "location_id"
    t.string "ip"
    t.integer "ram_mb"
    t.integer "cpus"
    t.integer "disk_gb"
    t.text "docker_snapshot"
    t.string "cloud_type"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["cloud_type"], name: "index_location_servers_on_cloud_type"
    t.index ["location_id"], name: "index_location_servers_on_location_id"
  end

  create_table "locations", charset: "latin1", force: :cascade do |t|
    t.string "str_id"
    t.string "full_name"
    t.string "country_fullname"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "cloud_provider", default: "internal"
  end

  create_table "newsletters", charset: "latin1", force: :cascade do |t|
    t.string "title"
    t.string "recipients_type"
    t.text "content", size: :medium
    t.text "custom_recipients", size: :medium
    t.text "emails_sent", size: :medium
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "notifications", charset: "latin1", force: :cascade do |t|
    t.string "type"
    t.string "level"
    t.text "content"
    t.bigint "website_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["website_id"], name: "index_notifications_on_website_id"
  end

  create_table "one_click_apps", charset: "latin1", force: :cascade do |t|
    t.string "name"
    t.text "prepare", size: :medium
    t.text "config", size: :medium
    t.text "dockerfile", size: :medium
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["name"], name: "index_one_click_apps_on_name", unique: true
  end

  create_table "orders", charset: "latin1", force: :cascade do |t|
    t.bigint "user_id"
    t.text "content"
    t.float "amount"
    t.string "payment_status"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "gateway", default: "paypal"
    t.boolean "is_subscription", default: false
    t.index ["user_id"], name: "index_orders_on_user_id"
  end

  create_table "snapshots", charset: "latin1", force: :cascade do |t|
    t.bigint "website_id", null: false
    t.string "status", default: "pending"
    t.datetime "expire_at"
    t.float "size_mb"
    t.string "uid"
    t.string "path"
    t.string "destination_path"
    t.string "url"
    t.text "steps", size: :medium
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "app", default: "www"
    t.index ["website_id"], name: "index_snapshots_on_website_id"
  end

  create_table "statuses", charset: "latin1", force: :cascade do |t|
    t.string "name"
    t.string "status"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["name"], name: "index_statuses_on_name", unique: true
  end

  create_table "subscription_websites", charset: "latin1", force: :cascade do |t|
    t.integer "website_id"
    t.bigint "subscription_id", null: false
    t.integer "quantity"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["subscription_id"], name: "index_subscription_websites_on_subscription_id"
    t.index ["website_id"], name: "index_subscription_websites_on_website_id"
  end

  create_table "subscriptions", charset: "latin1", force: :cascade do |t|
    t.integer "user_id"
    t.integer "quantity"
    t.boolean "active"
    t.string "subscription_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.datetime "expires_at", precision: 6
    t.index ["subscription_id"], name: "index_subscriptions_on_subscription_id", unique: true
    t.index ["user_id"], name: "index_subscriptions_on_user_id"
  end

  create_table "users", charset: "latin1", force: :cascade do |t|
    t.string "email"
    t.string "password_hash"
    t.string "reset_token"
    t.boolean "is_admin", default: false
    t.datetime "first_admin_entry_at"
    t.string "token"
    t.datetime "day_one_mail_at"
    t.float "credits", default: 0.0
    t.datetime "last_free_credit_distribute_at"
    t.datetime "last_admin_access_at", default: -> { "CURRENT_TIMESTAMP" }
    t.boolean "newsletter", default: true
    t.boolean "notified_low_credit", default: false
    t.text "coupons"
    t.float "nb_credits_threshold_notification", default: 50.0
    t.boolean "activated"
    t.string "activation_hash"
    t.boolean "suspended", default: false
    t.datetime "created_at", precision: 6
    t.datetime "updated_at", precision: 6
    t.text "account"
    t.string "latest_request_ip", default: ""
    t.index ["day_one_mail_at"], name: "index_users_on_day_one_mail_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["is_admin"], name: "index_users_on_is_admin"
    t.index ["last_free_credit_distribute_at"], name: "index_users_on_last_free_credit_distribute_at"
    t.index ["latest_request_ip"], name: "index_users_on_latest_request_ip"
    t.index ["newsletter"], name: "index_users_on_newsletter"
    t.index ["notified_low_credit"], name: "index_users_on_notified_low_credit"
    t.index ["token"], name: "index_users_on_token", unique: true
  end

  create_table "vaults", charset: "latin1", force: :cascade do |t|
    t.integer "ref_id"
    t.string "entity_type"
    t.text "encrypted_data"
    t.text "encrypted_data_iv"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["entity_type", "ref_id"], name: "index_vaults_on_entity_type_and_ref_id"
    t.index ["ref_id"], name: "index_vaults_on_ref_id"
  end

  create_table "viewed_notifications", charset: "latin1", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "notification_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["notification_id"], name: "index_viewed_notifications_on_notification_id"
    t.index ["user_id", "notification_id"], name: "index_viewed_notifications_on_user_id_and_notification_id"
    t.index ["user_id"], name: "index_viewed_notifications_on_user_id"
  end

  create_table "website_addons", charset: "latin1", force: :cascade do |t|
    t.bigint "website_id"
    t.bigint "addon_id"
    t.string "name"
    t.text "obj", size: :medium
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "account_type"
    t.integer "storage_gb", default: 0
    t.string "status", default: ""
    t.index ["website_id", "name"], name: "index_website_addons_on_website_id_and_name", unique: true
    t.index ["website_id"], name: "index_website_addons_on_website_id"
  end

  create_table "website_locations", charset: "latin1", force: :cascade do |t|
    t.bigint "website_id"
    t.bigint "location_id"
    t.bigint "location_server_id"
    t.integer "extra_storage", default: 0
    t.integer "nb_cpus", default: 1
    t.integer "port"
    t.integer "second_port"
    t.integer "running_port"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.text "obj"
    t.integer "replicas", default: 1
    t.boolean "load_balancer_synced", default: true
    t.string "execution_layer", default: "gcloud_run"
    t.index ["location_id"], name: "index_website_locations_on_location_id"
    t.index ["location_server_id"], name: "index_website_locations_on_location_server_id"
    t.index ["website_id"], name: "index_website_locations_on_website_id"
  end

  create_table "websites", charset: "latin1", force: :cascade do |t|
    t.bigint "user_id"
    t.string "site_name"
    t.text "data"
    t.datetime "last_access_at"
    t.string "status"
    t.string "type"
    t.boolean "http_port_available"
    t.datetime "first_online_at"
    t.string "account_type"
    t.datetime "credits_check_at"
    t.string "domain_type"
    t.string "domains"
    t.integer "nb_launch_issues"
    t.text "storage_areas"
    t.text "crontab"
    t.boolean "redir_http_to_https"
    t.text "configs"
    t.text "open_source"
    t.string "sub_status"
    t.string "cloud_type"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.boolean "open_source_activated", default: false
    t.text "alerts"
    t.string "auto_account_type", default: "third"
    t.text "auto_account_types_history"
    t.text "one_click_app", size: :medium
    t.string "version", default: ""
    t.index ["cloud_type"], name: "index_websites_on_cloud_type"
    t.index ["credits_check_at"], name: "index_websites_on_credits_check_at"
    t.index ["domains"], name: "index_websites_on_domains"
    t.index ["last_access_at"], name: "index_websites_on_last_access_at"
    t.index ["open_source_activated"], name: "index_websites_on_open_source_activated"
    t.index ["site_name"], name: "index_websites_on_site_name", unique: true
    t.index ["status"], name: "index_websites_on_status"
    t.index ["user_id"], name: "index_websites_on_user_id"
  end

  add_foreign_key "location_servers", "locations"
  add_foreign_key "subscription_websites", "subscriptions"
  add_foreign_key "website_locations", "location_servers"
  add_foreign_key "website_locations", "locations"
  add_foreign_key "website_locations", "websites"
  add_foreign_key "websites", "users"
end
