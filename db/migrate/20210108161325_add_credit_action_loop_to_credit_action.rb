class AddCreditActionLoopToCreditAction < ActiveRecord::Migration[6.0]
  def change
    add_column :credit_actions, :credit_action_loop_id, :bigint
    add_index :credit_actions, :credit_action_loop_id
  end
end
