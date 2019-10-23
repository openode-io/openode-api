# frozen_string_literal: true

class DropSomeUnusedTables < ActiveRecord::Migration[6.0]
  def change
    drop_table :community_comments
    drop_table :forum_followers
    drop_table :community_posts
  end
end
