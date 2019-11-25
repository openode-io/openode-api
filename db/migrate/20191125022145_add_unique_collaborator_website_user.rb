class AddUniqueCollaboratorWebsiteUser < ActiveRecord::Migration[6.0]
  def change
    add_index(:collaborators, [:website_id, :user_id], unique: true)
  end
end
