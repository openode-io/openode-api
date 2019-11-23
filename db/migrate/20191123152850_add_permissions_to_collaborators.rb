class AddPermissionsToCollaborators < ActiveRecord::Migration[6.0]
  def change
    add_column :collaborators, :permissions, :text, size: :medium
  end
end
