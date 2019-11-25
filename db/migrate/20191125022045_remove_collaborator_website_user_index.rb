class RemoveCollaboratorWebsiteUserIndex < ActiveRecord::Migration[6.0]
  def change
    remove_index "collaborators", name: "website_user_id_collaborators"
  end
end
