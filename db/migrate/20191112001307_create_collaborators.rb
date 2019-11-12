class CreateCollaborators < ActiveRecord::Migration[6.0]
  def change
    return unless ENV['DO_MIGRATIONS'] == 'true'

    create_table :collaborators do |t|
      t.references :website, null: false
      t.references :user, null: false

      t.timestamps
    end
  end
end
