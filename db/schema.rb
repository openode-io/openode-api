# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2021_01_05_004720) do

  create_table "addons", options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.string "name"
    t.string "category"
    t.text "obj"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["name"], name: "index_addons_on_name", unique: true
  end

  create_table "collaborators", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.integer "website_id"
    t.integer "user_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.text "permissions", size: :medium
    t.index ["website_id", "user_id"], name: "index_collaborators_on_website_id_and_user_id", unique: true
    t.index ["website_id"], name: "website_id_collaborators"
  end

  create_table "coupons", options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.string "str_id"
    t.float "extra_ratio_rebate"
    t.integer "nb_days_valid"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["str_id"], name: "index_coupons_on_str_id", unique: true
  end

  create_table "credit_actions", options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "website_id", null: false
    t.string "action_type"
    t.float "credits_spent"
    t.float "credits_remaining"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["user_id"], name: "index_credit_actions_on_user_id"
    t.index ["website_id"], name: "index_credit_actions_on_website_id"
  end

  create_table "executions", options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
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

  create_table "friend_invites", options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
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

  create_table "global_storages", options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.string "type"
    t.text "obj"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "histories", options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.integer "ref_id"
    t.string "type"
    t.text "obj", size: :medium
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["type", "ref_id"], name: "index_histories_on_type_and_ref_id"
    t.index ["type"], name: "index_histories_on_type"
  end

  create_table "location_servers", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.integer "location_id"
    t.string "ip", limit: 100
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "ram_mb"
    t.integer "cpus"
    t.integer "disk_gb"
    t.text "docker_snapshot"
    t.string "cloud_type", limit: 150, default: "cloud"
    t.index ["cloud_type"], name: "location_server_cloud_type"
    t.index ["location_id"], name: "location_id"
  end

  create_table "locations", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.string "full_name", limit: 100
    t.string "str_id", limit: 100
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "country_fullname", limit: 150, default: ""
    t.string "cloud_provider", default: "internal"
  end

  create_table "newsletters", options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.string "title"
    t.string "recipients_type"
    t.text "content", size: :medium
    t.text "custom_recipients", size: :medium
    t.text "emails_sent", size: :medium
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "notifications", options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.string "type"
    t.string "level"
    t.text "content"
    t.bigint "website_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["website_id"], name: "index_notifications_on_website_id"
  end

  create_table "orders", options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
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

  create_table "snapshots", options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
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

  create_table "statuses", options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.string "name"
    t.string "status"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["name"], name: "index_statuses_on_name", unique: true
  end

  create_table "subscriptions", options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.integer "user_id"
    t.integer "quantity"
    t.boolean "active"
    t.string "subscription_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["subscription_id"], name: "index_subscriptions_on_subscription_id", unique: true
    t.index ["user_id"], name: "index_subscriptions_on_user_id"
  end

  create_table "users", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.string "email"
    t.string "password_hash"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.timestamp "last_admin_access_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "reset_token", limit: 250, default: ""
    t.integer "is_admin", default: 0
    t.timestamp "first_admin_entry_at"
    t.string "token"
    t.timestamp "day_one_mail_at"
    t.float "credits", limit: 53, default: 0.0
    t.timestamp "last_free_credit_distribute_at", default: "1970-01-01 00:00:01", null: false
    t.integer "newsletter", limit: 1, default: 1
    t.boolean "notified_low_credit", default: false
    t.integer "has_free_sandbox", default: 0
    t.text "coupons"
    t.float "nb_credits_threshold_notification", default: 50.0
    t.integer "activated"
    t.string "activation_hash", limit: 200
    t.integer "suspended", limit: 1, default: 0
    t.text "account"
    t.string "latest_request_ip", default: ""
    t.index ["day_one_mail_at"], name: "users_day_one_mail_at"
    t.index ["email"], name: "users_email_unique", unique: true
    t.index ["is_admin"], name: "user_is_admin"
    t.index ["last_free_credit_distribute_at"], name: "last_free_credit_distribute_at_user_id"
    t.index ["newsletter"], name: "newsletter_users"
    t.index ["notified_low_credit"], name: "users_notified_low_credit"
    t.index ["reset_token"], name: "user_reset_token"
    t.index ["token"], name: "users_token", unique: true
  end

  create_table "vaults", options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.integer "ref_id"
    t.string "entity_type"
    t.text "encrypted_data"
    t.text "encrypted_data_iv"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["entity_type", "ref_id"], name: "index_vaults_on_entity_type_and_ref_id"
    t.index ["ref_id"], name: "index_vaults_on_ref_id"
  end

  create_table "viewed_notifications", options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "notification_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["notification_id"], name: "index_viewed_notifications_on_notification_id"
    t.index ["user_id", "notification_id"], name: "index_viewed_notifications_on_user_id_and_notification_id"
    t.index ["user_id"], name: "index_viewed_notifications_on_user_id"
  end

  create_table "website_addons", options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
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

  create_table "website_locations", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.integer "website_id"
    t.integer "location_id"
    t.integer "location_server_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "extra_storage", default: 0
    t.integer "port", default: 0
    t.integer "nb_cpus", default: 1
    t.integer "second_port"
    t.integer "running_port"
    t.text "obj"
    t.integer "replicas", default: 1
    t.index ["location_id"], name: "location_id"
    t.index ["location_server_id"], name: "location_server_id"
    t.index ["website_id"], name: "website_id"
  end

  create_table "websites", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.integer "user_id"
    t.string "site_name"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.text "data"
    t.text "pm2_info"
    t.boolean "valid"
    t.timestamp "last_access_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "status", default: "N/A"
    t.string "type", limit: 100, default: "nodejs"
    t.integer "http_port_available", default: 0
    t.timestamp "first_online_at"
    t.string "account_type", limit: 100, default: "free"
    t.timestamp "credits_check_at", default: "1970-01-01 00:00:01", null: false
    t.string "domain_type", limit: 100, default: "subdomain"
    t.string "domains", limit: 3000
    t.integer "nb_launch_issues", default: 0
    t.text "storage_areas"
    t.string "container_id", limit: 200
    t.text "crontab"
    t.boolean "redir_http_to_https", default: false
    t.text "configs"
    t.text "open_source"
    t.string "instance_type", limit: 50, default: "server"
    t.string "sub_status"
    t.string "cloud_type", limit: 150, default: "cloud"
    t.text "init_script"
    t.boolean "open_source_activated", default: false
    t.text "alerts"
    t.string "auto_account_type", default: "third"
    t.text "auto_account_types_history"
    t.index ["cloud_type"], name: "website_cloud_type"
    t.index ["credits_check_at"], name: "credits_check_at_website_id"
    t.index ["domains"], name: "domains_websites"
    t.index ["last_access_at"], name: "website_last_access_at"
    t.index ["open_source_activated"], name: "index_websites_on_open_source_activated"
    t.index ["site_name"], name: "website_sitename", unique: true
    t.index ["status"], name: "website_status"
    t.index ["valid"], name: "website_valid"
  end

  add_foreign_key "location_servers", "locations", name: "location_servers_ibfk_1"
  add_foreign_key "website_locations", "locations", name: "website_locations_ibfk_2"
  add_foreign_key "website_locations", "websites", name: "website_locations_ibfk_1", on_delete: :cascade
end
