class User < ApplicationRecord

  has_many :websites

  validates :email, presence: true
  validates :token, presence: true
  validates :password_hash, presence: true

  validates :email, uniqueness: true
  validates :token, uniqueness: true

end
