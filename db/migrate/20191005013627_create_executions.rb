# frozen_string_literal: true

class CreateExecutions < ActiveRecord::Migration[6.0]
  def change
    create_table :executions do |t|
      t.references :website, null: false
      t.references :website_location, null: false
      t.string :status
      t.text :result, size: :medium

      t.timestamps
    end
  end
end
