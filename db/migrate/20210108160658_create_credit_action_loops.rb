class CreateCreditActionLoops < ActiveRecord::Migration[6.0]
  def change
    create_table :credit_action_loops do |t|
      t.string :type

      t.timestamps
    end
  end
end
