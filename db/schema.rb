# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2019_08_10_230826) do

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
    t.text "config"
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

  add_foreign_key "websites", "users"
end
