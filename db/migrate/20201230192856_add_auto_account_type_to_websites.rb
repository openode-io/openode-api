class AddAutoAccountTypeToWebsites < ActiveRecord::Migration[6.0]
  def change
    add_column :websites, :auto_account_type, :string, default: "third"
  end
end
