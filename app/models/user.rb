
require 'bcrypt'

class User < ApplicationRecord
  NotAuthorized = Class.new(StandardError)

  has_many :websites

  validates :email, presence: true
  validates :token, presence: true
  validates :password_hash, presence: true

  validates :email, uniqueness: true
  validates :token, uniqueness: true

  def before_save
    self.password_hash = User.encrypt_passwd(self.password_hash)
  end

  def authenticate!(passwd)
    if ! User.passwd_valid?(self.password_hash, passwd)
      raise NotAuthorized.new("Not authorized")
    end
  end

  def self.encrypt_passwd(passwd, salt = ENV["AUTH_SALT"])
    BCrypt::Engine.hash_secret(passwd, salt)
  end

  def self.passwd_valid?(hashed_passwd, expected_passwd)
    p = BCrypt::Password.new(hashed_passwd)

    p == expected_passwd
  end

end
