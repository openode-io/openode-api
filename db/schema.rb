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

ActiveRecord::Schema.define(version: 2019_08_29_234338) do

  create_table "histories", options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.integer "ref_id"
    t.string "type"
    t.text "obj"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["type", "ref_id"], name: "index_histories_on_type_and_ref_id"
    t.index ["type"], name: "index_histories_on_type"
  end

  create_table "location_servers", options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.bigint "location_id"
    t.string "ip"
    t.string "user"
    t.string "password"
    t.integer "ram_mb"
    t.integer "cpus"
    t.integer "disk_gb"
    t.text "docker_snapshot"
    t.string "cloud_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cloud_type"], name: "index_location_servers_on_cloud_type"
    t.index ["location_id"], name: "index_location_servers_on_location_id"
  end

  create_table "locations", options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.string "str_id"
    t.string "full_name"
    t.string "country_fullname"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
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
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }
    t.datetime "updated_at", default: -> { "CURRENT_TIMESTAMP" }
    t.index ["day_one_mail_at"], name: "index_users_on_day_one_mail_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["is_admin"], name: "index_users_on_is_admin"
    t.index ["last_free_credit_distribute_at"], name: "index_users_on_last_free_credit_distribute_at"
    t.index ["newsletter"], name: "index_users_on_newsletter"
    t.index ["notified_low_credit"], name: "index_users_on_notified_low_credit"
    t.index ["token"], name: "index_users_on_token", unique: true
  end

  create_table "website_locations", options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.bigint "website_id"
    t.bigint "location_id"
    t.bigint "location_server_id"
    t.integer "extra_storage"
    t.integer "nb_cpus"
    t.integer "port"
    t.integer "second_port"
    t.integer "running_port"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["location_id"], name: "index_website_locations_on_location_id"
    t.index ["location_server_id"], name: "index_website_locations_on_location_server_id"
    t.index ["website_id"], name: "index_website_locations_on_website_id"
  end

  create_table "websites", options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.bigint "user_id"
    t.string "site_name"
    t.text "data"
    t.text "pm2_info"
    t.boolean "valid"
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
    t.string "container_id"
    t.text "crontab"
    t.boolean "redir_http_to_https"
    t.text "configs"
    t.text "open_source"
    t.string "instance_type"
    t.string "sub_status"
    t.text "dns"
    t.boolean "is_educational"
    t.string "cloud_type"
    t.text "init_script"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cloud_type"], name: "index_websites_on_cloud_type"
    t.index ["credits_check_at"], name: "index_websites_on_credits_check_at"
    t.index ["domains"], name: "index_websites_on_domains"
    t.index ["last_access_at"], name: "index_websites_on_last_access_at"
    t.index ["site_name"], name: "index_websites_on_site_name", unique: true
    t.index ["status"], name: "index_websites_on_status"
    t.index ["user_id"], name: "index_websites_on_user_id"
    t.index ["valid"], name: "index_websites_on_valid"
  end

  add_foreign_key "location_servers", "locations"
  add_foreign_key "website_locations", "location_servers"
  add_foreign_key "website_locations", "locations"
  add_foreign_key "website_locations", "websites"
  add_foreign_key "websites", "users"
end
