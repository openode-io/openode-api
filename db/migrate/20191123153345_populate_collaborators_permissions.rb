class PopulateCollaboratorsPermissions < ActiveRecord::Migration[6.0]
  def up
    Collaborator.all.each do |collaborator|
      collaborator.permissions = [Collaborator::PERMISSION_ROOT]
      collaborator.save!
    end
  end

  def down; end
end
