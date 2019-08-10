class AddNewsletterIndexToUsers < ActiveRecord::Migration[5.2]
  def change
    add_index :users, :newsletter
  end
end
