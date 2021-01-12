class AddIndexCreditActionLoopType < ActiveRecord::Migration[6.0]
  def change
    add_index :credit_action_loops, :type
  end
end
