class AddLastFreeCreditDistributeAtIndexToUsers < ActiveRecord::Migration[5.2]
  def change
    add_index :users, :last_free_credit_distribute_at
  end
end
