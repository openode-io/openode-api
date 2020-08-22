class AddIndexToAddonsName < ActiveRecord::Migration[6.0]
  def change
    add_index(:addons, [:name], unique: true)
  end
end
