class CreateNewsletters < ActiveRecord::Migration[6.0]
  def change
    create_table :newsletters do |t|
      t.string :title
      t.string :recipients_type
      t.text :content, size: :medium
      t.text :custom_recipients, size: :medium
      t.text :emails_sent, size: :medium

      t.timestamps
    end
  end
end
