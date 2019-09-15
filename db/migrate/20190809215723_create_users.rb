class CreateUsers < ActiveRecord::Migration[5.2]
  def change
    create_table :users do |t|
      t.string :email
      t.string :password_hash
      t.string :reset_token
      t.boolean :is_admin, :default => 0
      t.datetime :first_admin_entry_at
      t.string :token
      t.datetime :day_one_mail_at
      t.float :credits, :default => 0
      t.datetime :last_free_credit_distribute_at
      t.datetime :last_admin_access_at, default: -> { 'CURRENT_TIMESTAMP' }
      t.boolean :newsletter, :default => 1
      t.boolean :notified_low_credit, :default => 0
      t.text :coupons
      t.float :nb_credits_threshold_notification, :default => 50
      t.boolean :activated
      t.string :activation_hash
      t.boolean :suspended, :default => 0
      t.datetime :created_at, default: -> { 'CURRENT_TIMESTAMP' }
      t.datetime :updated_at, default: -> { 'CURRENT_TIMESTAMP' }
    end if ENV["DO_MIGRATIONS"] == "true"
  end
end
