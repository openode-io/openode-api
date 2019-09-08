class Status < ApplicationRecord

  validates :name, uniqueness: true

end
