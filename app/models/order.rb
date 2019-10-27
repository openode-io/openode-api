class Order < ApplicationRecord
  serialize :content, JSON

  belongs_to :user
end
