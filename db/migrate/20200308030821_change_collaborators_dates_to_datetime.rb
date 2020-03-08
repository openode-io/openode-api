class ChangeCollaboratorsDatesToDatetime < ActiveRecord::Migration[6.0]
  def change
    change_column :collaborators, :created_at, :datetime, precision: 6
    change_column :collaborators, :updated_at, :datetime, precision: 6
  end
end
