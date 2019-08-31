class CreateWebsites < ActiveRecord::Migration[5.2]
  def change
    create_table :websites do |t|
      t.references :user, foreign_key: true
      t.string :site_name
      t.text :data
      t.text :pm2_info
      t.boolean :valid
      t.datetime :last_access_at
      t.string :status
      t.string :type
      t.boolean :http_port_available
      t.datetime :first_online_at
      t.string :account_type
      t.datetime :credits_check_at
      t.string :domain_type
      t.string :domains, length: 3000
      t.integer :nb_launch_issues
      t.text :storage_areas
      t.string :container_id
      t.text :crontab
      t.boolean :redir_http_to_https
      t.text :configs
      t.text :open_source
      t.string :instance_type
      t.string :sub_status
      t.text :dns
      t.boolean :is_educational
      t.string :cloud_type
      t.text :init_script

      t.timestamps
    end  if ENV["DO_MIGRATIONS"]
  end
end
