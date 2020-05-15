class AddUniqueIndexCouponStrId < ActiveRecord::Migration[6.0]
  def change
    add_index :coupons, :str_id, unique: true
  end
end
