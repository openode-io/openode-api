class AddUniqueIndexStatusesName < ActiveRecord::Migration[6.0]
  def change
    add_index :statuses, :name, unique: true
  end
end
