class CreateCreditActions < ActiveRecord::Migration[6.0]
  def change
    create_table :credit_actions do |t|
      t.references :user, null: false
      t.references :website, null: false
      t.string :action_type
      t.float :credits_spent
      t.float :credits_remaining

      t.timestamps
    end
  end
end
