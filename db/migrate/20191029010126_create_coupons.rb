class CreateCoupons < ActiveRecord::Migration[6.0]
  def change
    create_table :coupons do |t|
      t.string :str_id
      t.float :extra_ratio_rebate
      t.integer :nb_days_valid

      t.timestamps
    end
  end
end
