class OneClickApp < ApplicationRecord
  serialize :config, JSON

  validates :name, presence: true
end
