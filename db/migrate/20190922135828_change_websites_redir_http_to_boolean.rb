class ChangeWebsitesRedirHttpToBoolean < ActiveRecord::Migration[6.0]
  def change
  	change_column :websites, :redir_http_to_https, :boolean
  end
end
