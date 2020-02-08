class RemoveUniquePortIndexWebsiteLocations < ActiveRecord::Migration[6.0]
  def change
    begin
      remove_foreign_key :website_locations, name: "website_locations_ibfk_3"
    rescue StandardError => e
      Rails.logger.error("Issue removing fk #{e}")
    end

    remove_index :website_locations, column: [:location_server_id, :port]
  end
end
