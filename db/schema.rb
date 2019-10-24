# frozen_string_literal: true

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

ActiveRecord::Schema.define(version: 20_191_014_223_950) do
  create_table 'collaborators', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=latin1', force: :cascade do |t|
    t.integer 'website_id'
    t.integer 'user_id'
    t.timestamp 'created_at', default: -> { 'CURRENT_TIMESTAMP' }, null: false
    t.timestamp 'updated_at', default: -> { 'CURRENT_TIMESTAMP' }, null: false
    t.index %w[website_id user_id], name: 'website_user_id_collaborators'
    t.index ['website_id'], name: 'website_id_collaborators'
  end

  create_table 'credit_actions', options: 'ENGINE=InnoDB DEFAULT CHARSET=latin1', force: :cascade do |t|
    t.bigint 'user_id', null: false
    t.bigint 'website_id', null: false
    t.string 'action_type'
    t.float 'credits_spent'
    t.float 'credits_remaining'
    t.datetime 'created_at', precision: 6, null: false
    t.datetime 'updated_at', precision: 6, null: false
    t.index ['user_id'], name: 'index_credit_actions_on_user_id'
    t.index ['website_id'], name: 'index_credit_actions_on_website_id'
  end

  create_table 'delayed_jobs', options: 'ENGINE=InnoDB DEFAULT CHARSET=latin1', force: :cascade do |t|
    t.integer 'priority', default: 0, null: false
    t.integer 'attempts', default: 0, null: false
    t.text 'handler', null: false
    t.text 'last_error'
    t.datetime 'run_at'
    t.datetime 'locked_at'
    t.datetime 'failed_at'
    t.string 'locked_by'
    t.string 'queue'
    t.datetime 'created_at', precision: 6
    t.datetime 'updated_at', precision: 6
    t.index %w[priority run_at], name: 'delayed_jobs_priority'
  end

  create_table 'docs', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=latin1', force: :cascade do |t|
    t.string 'title', limit: 500
    t.text 'content', size: :medium
    t.timestamp 'created_at', default: -> { 'CURRENT_TIMESTAMP' }, null: false
    t.timestamp 'updated_at', default: -> { 'CURRENT_TIMESTAMP' }, null: false
    t.string 'type', limit: 50, default: 'news'
    t.string 'short', limit: 500, default: ''
  end

  create_table 'executions', options: 'ENGINE=InnoDB DEFAULT CHARSET=latin1', force: :cascade do |t|
    t.bigint 'website_id', null: false
    t.bigint 'website_location_id', null: false
    t.string 'status'
    t.text 'result', size: :medium
    t.datetime 'created_at', precision: 6, null: false
    t.datetime 'updated_at', precision: 6, null: false
    t.string 'type', default: 'Deployment'
    t.index ['website_id'], name: 'index_executions_on_website_id'
    t.index ['website_location_id'], name: 'index_executions_on_website_location_id'
  end

  create_table 'histories', options: 'ENGINE=InnoDB DEFAULT CHARSET=latin1', force: :cascade do |t|
    t.integer 'ref_id'
    t.string 'type'
    t.text 'obj', size: :medium
    t.datetime 'created_at', precision: 6, null: false
    t.datetime 'updated_at', precision: 6, null: false
    t.index %w[type ref_id], name: 'index_histories_on_type_and_ref_id'
    t.index ['type'], name: 'index_histories_on_type'
  end

  create_table 'location_servers', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=latin1', force: :cascade do |t|
    t.integer 'location_id'
    t.string 'ip', limit: 100
    t.timestamp 'created_at', default: -> { 'CURRENT_TIMESTAMP' }, null: false
    t.timestamp 'updated_at', default: -> { 'CURRENT_TIMESTAMP' }, null: false
    t.integer 'ram_mb'
    t.integer 'cpus'
    t.integer 'disk_gb'
    t.text 'docker_snapshot'
    t.string 'cloud_type', limit: 150, default: 'cloud'
    t.index ['cloud_type'], name: 'location_server_cloud_type'
    t.index ['location_id'], name: 'location_id'
  end

  create_table 'locations', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=latin1', force: :cascade do |t|
    t.string 'full_name', limit: 100
    t.string 'str_id', limit: 100
    t.timestamp 'created_at', default: -> { 'CURRENT_TIMESTAMP' }, null: false
    t.timestamp 'updated_at', default: -> { 'CURRENT_TIMESTAMP' }, null: false
    t.string 'country_fullname', limit: 150, default: ''
    t.string 'cloud_provider', default: 'internal'
  end

  create_table 'logs', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=latin1', force: :cascade do |t|
    t.string 'type', limit: 100
    t.integer 'ref_id'
    t.string 'content', limit: 1000
    t.timestamp 'created_at', default: -> { 'CURRENT_TIMESTAMP' }, null: false
    t.timestamp 'updated_at', default: -> { 'CURRENT_TIMESTAMP' }, null: false
    t.index ['ref_id'], name: 'log_ref_id'
    t.index ['type'], name: 'log_type'
  end

  create_table 'news', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=latin1', force: :cascade do |t|
    t.string 'title', limit: 500
    t.text 'content', size: :medium
    t.timestamp 'created_at', default: -> { 'CURRENT_TIMESTAMP' }, null: false
    t.timestamp 'updated_at', default: -> { 'CURRENT_TIMESTAMP' }, null: false
    t.string 'type', limit: 50, default: 'news'
  end

  create_table 'orders', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=latin1', force: :cascade do |t|
    t.integer 'user_id'
    t.text 'content', size: :medium
    t.float 'amount', limit: 53
    t.timestamp 'created_at', default: -> { 'CURRENT_TIMESTAMP' }, null: false
    t.timestamp 'updated_at', default: -> { 'CURRENT_TIMESTAMP' }, null: false
    t.string 'payment_status', default: 'Completed'
    t.index ['user_id'], name: 'user_id'
  end

  create_table 'snapshots', options: 'ENGINE=InnoDB DEFAULT CHARSET=latin1', force: :cascade do |t|
    t.bigint 'user_id', null: false
    t.bigint 'website_id', null: false
    t.string 'name'
    t.string 'status', default: 'pending'
    t.float 'tx_time_in_sec'
    t.float 'size_in_mb'
    t.text 'details'
    t.datetime 'created_at', precision: 6, null: false
    t.datetime 'updated_at', precision: 6, null: false
    t.index ['user_id'], name: 'index_snapshots_on_user_id'
    t.index ['website_id'], name: 'index_snapshots_on_website_id'
  end

  create_table 'stats', id: false, options: 'ENGINE=InnoDB DEFAULT CHARSET=latin1', force: :cascade do |t|
    t.integer 'basic_up'
    t.integer 'nodejs_up'
    t.timestamp 'last_status_at', default: -> { 'CURRENT_TIMESTAMP' }, null: false
  end

  create_table 'statuses', options: 'ENGINE=InnoDB DEFAULT CHARSET=latin1', force: :cascade do |t|
    t.string 'name'
    t.string 'status'
    t.datetime 'created_at', precision: 6, null: false
    t.datetime 'updated_at', precision: 6, null: false
  end

  create_table 'users', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=latin1', force: :cascade do |t|
    t.string 'email'
    t.string 'password_hash'
    t.timestamp 'created_at', default: -> { 'CURRENT_TIMESTAMP' }, null: false
    t.timestamp 'updated_at', default: -> { 'CURRENT_TIMESTAMP' }, null: false
    t.timestamp 'last_admin_access_at', default: -> { 'CURRENT_TIMESTAMP' }, null: false
    t.string 'reset_token', limit: 250, default: ''
    t.integer 'is_admin', default: 0
    t.timestamp 'first_admin_entry_at'
    t.string 'token'
    t.timestamp 'day_one_mail_at'
    t.float 'credits', limit: 53, default: 0.0
    t.timestamp 'last_free_credit_distribute_at', default: '1970-01-01 00:00:01', null: false
    t.integer 'newsletter', limit: 1, default: 1
    t.integer 'notified_low_credit', default: 0
    t.integer 'has_free_sandbox', default: 0
    t.text 'coupons'
    t.float 'nb_credits_threshold_notification', default: 50.0
    t.integer 'activated'
    t.string 'activation_hash', limit: 200
    t.integer 'suspended', limit: 1, default: 0
    t.index ['day_one_mail_at'], name: 'users_day_one_mail_at'
    t.index ['email'], name: 'users_email_unique', unique: true
    t.index ['is_admin'], name: 'user_is_admin'
    t.index ['last_free_credit_distribute_at'], name: 'last_free_credit_distribute_at_user_id'
    t.index ['newsletter'], name: 'newsletter_users'
    t.index ['notified_low_credit'], name: 'users_notified_low_credit'
    t.index ['reset_token'], name: 'user_reset_token'
    t.index ['token'], name: 'users_token', unique: true
  end

  create_table 'vault', options: 'ENGINE=InnoDB DEFAULT CHARSET=latin1', force: :cascade do |t|
    t.bigint 'ref_id', null: false
    t.text 'data'
    t.timestamp 'created_at', default: -> { 'CURRENT_TIMESTAMP' }, null: false
    t.timestamp 'updated_at', default: -> { 'CURRENT_TIMESTAMP' }, null: false
    t.index ['ref_id'], name: 'ref_id_ind'
  end

  create_table 'vaults', options: 'ENGINE=InnoDB DEFAULT CHARSET=latin1', force: :cascade do |t|
    t.integer 'ref_id'
    t.string 'entity_type'
    t.text 'encrypted_data'
    t.text 'encrypted_data_iv'
    t.datetime 'created_at', precision: 6, null: false
    t.datetime 'updated_at', precision: 6, null: false
    t.index %w[entity_type ref_id], name: 'index_vaults_on_entity_type_and_ref_id'
    t.index ['ref_id'], name: 'index_vaults_on_ref_id'
  end

  create_table 'website_locations', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=latin1', force: :cascade do |t|
    t.integer 'website_id'
    t.integer 'location_id'
    t.integer 'location_server_id'
    t.timestamp 'created_at', default: -> { 'CURRENT_TIMESTAMP' }, null: false
    t.timestamp 'updated_at', default: -> { 'CURRENT_TIMESTAMP' }, null: false
    t.integer 'extra_storage', default: 0
    t.integer 'port', default: 0
    t.integer 'nb_cpus', default: 1
    t.integer 'second_port'
    t.integer 'running_port'
    t.index ['location_id'], name: 'location_id'
    t.index %w[location_server_id port], name: 'unique_port_index', unique: true
    t.index ['location_server_id'], name: 'location_server_id'
    t.index ['website_id'], name: 'website_id'
  end

  create_table 'website_stats', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=latin1', force: :cascade do |t|
    t.integer 'website_id'
    t.string 'type', limit: 50
    t.float 'value', limit: 53
    t.date 'on_date'
    t.timestamp 'created_at', default: -> { 'CURRENT_TIMESTAMP' }, null: false
    t.timestamp 'updated_at', default: -> { 'CURRENT_TIMESTAMP' }, null: false
    t.index %w[website_id type on_date], name: 'website_stat_id_type_on_date'
    t.index %w[website_id type], name: 'website_stat_id_type'
    t.index ['website_id'], name: 'website_stat_id'
  end

  create_table 'websites', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=latin1', force: :cascade do |t|
    t.integer 'user_id'
    t.string 'site_name'
    t.timestamp 'created_at', default: -> { 'CURRENT_TIMESTAMP' }, null: false
    t.timestamp 'updated_at', default: -> { 'CURRENT_TIMESTAMP' }, null: false
    t.text 'data'
    t.text 'pm2_info'
    t.boolean 'valid'
    t.timestamp 'last_access_at', default: -> { 'CURRENT_TIMESTAMP' }, null: false
    t.string 'status', default: 'N/A'
    t.string 'type', limit: 100, default: 'nodejs'
    t.integer 'http_port_available', default: 0
    t.timestamp 'first_online_at'
    t.string 'account_type', limit: 100, default: 'free'
    t.timestamp 'credits_check_at', default: '1970-01-01 00:00:01', null: false
    t.string 'domain_type', limit: 100, default: 'subdomain'
    t.string 'domains', limit: 3000
    t.integer 'nb_launch_issues', default: 0
    t.text 'storage_areas'
    t.string 'container_id', limit: 200
    t.text 'crontab'
    t.boolean 'redir_http_to_https', default: false
    t.text 'configs'
    t.text 'open_source'
    t.string 'instance_type', limit: 50, default: 'server'
    t.string 'sub_status'
    t.text 'dns'
    t.integer 'is_educational', default: 0
    t.string 'cloud_type', limit: 150, default: 'cloud'
    t.text 'init_script'
    t.index ['cloud_type'], name: 'website_cloud_type'
    t.index ['credits_check_at'], name: 'credits_check_at_website_id'
    t.index ['domains'], name: 'domains_websites'
    t.index ['last_access_at'], name: 'website_last_access_at'
    t.index ['site_name'], name: 'website_sitename', unique: true
    t.index ['status'], name: 'website_status'
    t.index ['valid'], name: 'website_valid'
  end

  add_foreign_key 'location_servers', 'locations', name: 'location_servers_ibfk_1'
  add_foreign_key 'orders', 'users', name: 'orders_ibfk_1'
  add_foreign_key 'website_locations', 'location_servers',
                  name: 'website_locations_ibfk_3'
  add_foreign_key 'website_locations', 'locations', name: 'website_locations_ibfk_2'
  add_foreign_key 'website_locations', 'websites', name: 'website_locations_ibfk_1', on_delete: :cascade
end
