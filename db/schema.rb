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

ActiveRecord::Schema.define(version: 2019_08_10_022400) do

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
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["token"], name: "index_users_on_token", unique: true
  end

end
