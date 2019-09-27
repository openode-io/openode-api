
require 'bcrypt'

class User < ApplicationRecord
  NotAuthorized = Class.new(StandardError)

  DISALLOWED_EMAIL_DOMAINS = [
    "cuvox.de",
    "superrito.com",
    "teleworm.us",
    "jourrapide.com",
    "gustr.com",
    "dayrep.com",
    "fleckens.hu",
    "einrot.com",
    "armyspy.com"
  ]

  alias_attribute :password, :password_hash
  attr_accessor   :password_confirmation

  has_many :websites
  has_many :snapshots

  validates :email, uniqueness: true
  validates :email, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validate :email_should_not_have_a_blacklisted_domain

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

  validate :verify_passwords_match, on: :create

  def verify_passwords_match
    if self.password_confirmation && self.password != self.password_confirmation
      self.errors.add(:password_confirmation, "The password verification does not match.")
    end
  end

  def email_should_not_have_a_blacklisted_domain
    email_domain = self.email.split("@").last

    if User::DISALLOWED_EMAIL_DOMAINS.include?(email_domain)
      self.errors.add(:email, "Blacklisted domain")
    end
  end

  before_validation do
    self.activated = false if self.activated.nil?
    self.activation_hash ||= SecureRandom.hex(16)
    self.token ||= SecureRandom.hex(16)
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

  def has_credits?
    self.credits > 0
  end

end
