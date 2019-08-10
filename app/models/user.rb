class User < ApplicationRecord

  validates :email, uniqueness: true
  validates :token, uniqueness: true

end
