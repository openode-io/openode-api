class WebsiteLocationLoadBalancerSynced < ActiveRecord::Migration[6.1]
  def change
    add_column :website_locations, :load_balancer_synced, :boolean, default: true
  end
end
