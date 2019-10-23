# frozen_string_literal: true

class CreateStatuses < ActiveRecord::Migration[6.0]
  def change
    create_table :statuses do |t|
      t.string :name
      t.string :status

      t.timestamps
    end
  end
end
