class CreateOrders < ActiveRecord::Migration[6.0]
  def change
    return unless ENV['DO_MIGRATIONS'] == 'true'

    create_table :orders do |t|
      t.references :user
      t.text :content
      t.float :amount
      t.string :payment_status

      t.timestamps
    end
  end
end
