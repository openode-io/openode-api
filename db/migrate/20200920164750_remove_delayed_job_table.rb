class RemoveDelayedJobTable < ActiveRecord::Migration[6.0]
  def self.up
    drop_table :delayed_jobs
  end
end
