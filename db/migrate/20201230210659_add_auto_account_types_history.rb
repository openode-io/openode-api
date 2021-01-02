class AddAutoAccountTypesHistory < ActiveRecord::Migration[6.0]
  def change
    add_column :websites, :auto_account_types_history, :text
  end
end
