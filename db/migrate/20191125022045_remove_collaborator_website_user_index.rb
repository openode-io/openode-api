class RemoveCollaboratorWebsiteUserIndex < ActiveRecord::Migration[6.0]
  def change
    remove_index "collaborators", name: "index_collaborators_on_user_id"
  end
end
