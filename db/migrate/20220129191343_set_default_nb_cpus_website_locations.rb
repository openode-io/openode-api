class SetDefaultNbCpusWebsiteLocations < ActiveRecord::Migration[6.1]
  def change
    change_column_default(:website_locations, :nb_cpus, 1)
  end
end
