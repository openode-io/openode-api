class AddExecutionLayerWebsiteLocation < ActiveRecord::Migration[6.1]
  def change
    add_column :website_locations, :execution_layer, :string, default: "gcloud_run"
  end
end
