
require 'bcrypt'

class User < ApplicationRecord
  NotAuthorized = Class.new(StandardError)

  has_many :websites

  validates :email, uniqueness: true
  validates :email, presence: true
  validates :token, uniqueness: true
  validates :token, presence: true

  validates :password_hash, presence: true
  PASSWORD_FORMAT = /\A
    (?=.{8,})          # Must contain 8 or more characters
    (?=.*\d)           # Must contain a digit
    (?=.*[a-z])        # Must contain a lower case character
    (?=.*[A-Z])        # Must contain an upper case character
  /x
  validates :password_hash, { format: {
      with: PASSWORD_FORMAT,
      message: "must contain: 8 characters, a lowercase letter, an uppercase letter, a digit"
    }
  }

  before_validation do
    self.activated = false if self.activated.nil?
    self.activation_hash ||= SecureRandom.hex(16)
    self.email = self.email.downcase if self.email
  end

  after_validation do
    self.password_hash = User.encrypt_passwd(self.password_hash)
  end

  def self.encrypt_passwd(passwd, salt = ENV["AUTH_SALT"])
    BCrypt::Engine.hash_secret(passwd, salt)
  end

  def self.passwd_valid?(hashed_passwd, expected_passwd)
    p = BCrypt::Password.new(hashed_passwd)

    p == expected_passwd
  end

  def verify_authentication(passwd)
    if ! User.passwd_valid?(self.password_hash, passwd)
      raise NotAuthorized.new("Not authorized")
    end
  end

  def regen_api_token!
    self.token = SecureRandom.hex(16)
    self.save
  end

end
