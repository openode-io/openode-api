require 'bcrypt'
require 'neverbounce'

class User < ApplicationRecord
  serialize :coupons, JSON
  serialize :account, JSON

  NotAuthorized = Class.new(StandardError)
  Forbidden = Class.new(StandardError)
  TooManyRequests = Class.new(StandardError)

  DISALLOWED_EMAIL_DOMAINS = [
    'cuvox.de',
    'superrito.com',
    'teleworm.us',
    'jourrapide.com',
    'gustr.com',
    'dayrep.com',
    'fleckens.hu',
    'einrot.com',
    'armyspy.com'
  ].freeze

  # alias_attribute :password, :password_hash
  attr_accessor   :password
  attr_accessor   :password_confirmation

  has_many :websites, dependent: :destroy
  has_many :orders, dependent: :destroy
  has_many :collaborators, dependent: :destroy
  has_many :viewed_notifications, dependent: :destroy
  has_many :friend_invites, dependent: :destroy
  has_many :subscriptions, dependent: :destroy
  has_many :user_email_verifications, foreign_key: :ref_id,
                                      class_name: :UserEmailVerification,
                                      dependent: :destroy

  scope :lacking_credits, -> { where('credits < nb_credits_threshold_notification') }
  scope :not_notified_low_credit, -> { where(notified_low_credit: 0) }
  scope :having_websites_in_statuses, lambda { |statuses|
    where('EXISTS(SELECT 1 ' \
      'FROM websites w ' \
      'WHERE w.user_id = users.id AND w.status IN (?))', statuses)
  }

  validates_uniqueness_of :email, case_sensitive: true
  validates :email, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validate :email_should_not_have_a_blacklisted_domain

  validates :password, presence: true, on: :create
  PASSWORD_FORMAT = /\A
    (?=.{8,})          # Must contain 8 or more characters
    (?=.*\d)           # Must contain a digit
    (?=.*[a-z])        # Must contain a lower case character
    (?=.*[A-Z])        # Must contain an upper case character
  /x.freeze
  validates :password, if: :password?, format: {
    with: PASSWORD_FORMAT,
    message: 'must contain: 8 characters, a lowercase letter, an uppercase letter, a digit'
  }

  validate :verify_passwords_match, on: :create

  after_create :send_registration_email
  after_create :record_free_credit_distributed
  after_update :send_registration_email_on_mail_changed
  before_update :mark_changing_email
  before_destroy :ensure_no_active_website, prepend: true

  def active_subscription?
    subscriptions.exists?(active: true)
  end

  def password?
    password.present?
  end

  def verify_passwords_match
    if password_confirmation && password != password_confirmation
      errors.add(:password_confirmation, 'The password verification does not match.')
    end
  end

  def email_should_not_have_a_blacklisted_domain
    email_domain = email.split('@').last

    if User::DISALLOWED_EMAIL_DOMAINS.include?(email_domain)
      errors.add(:email, 'Blacklisted domain')
    end
  end

  def send_registration_email
    UserMailer.with(user: self).registration.deliver_now
  end

  def record_free_credit_distributed
    GlobalEmailRegistration.create(key: email)
  end

  def mark_changing_email
    return unless email_changed?

    redo_activation
  end

  def send_registration_email_on_mail_changed
    return if saved_changes['email'].blank?

    send_registration_email
  end

  def self.gen_activation_hash
    SecureRandom.hex(16)
  end

  before_validation do
    self.activated = false if activated.nil?
    self.activation_hash ||= User.gen_activation_hash
    self.token ||= SecureRandom.hex(16)
    self.email = email.downcase if email
  end

  after_validation do
    if password?
      self.password_hash = User.encrypt_passwd(password)
    end

    errors.add(:password_hash, "The password can't be blank.") unless password_hash
  end

  before_validation :distribute_free_credits, on: :create

  def self.encrypt_passwd(passwd, salt = ENV['AUTH_SALT'])
    BCrypt::Engine.hash_secret(passwd, salt)
  end

  def self.passwd_valid?(hashed_passwd, expected_passwd)
    p = BCrypt::Password.new(hashed_passwd)

    p == expected_passwd
  end

  def type
    [1, true].include?(is_admin) ? 'admin' : 'regular'
  end

  def admin?
    type == 'admin'
  end

  def active_websites?
    websites.any?(&:active?)
  end

  def ensure_no_active_website
    if active_websites?
      raise ValidationError, "Some websites are still active (online or with storage)."
    end
  end

  def distribute_free_credits
    return if GlobalEmailRegistration.exists?(key: email)

    internal_provider = CloudProvider::Manager.instance.first_of_type('internal')

    plan = internal_provider.plans.find { |p| p[:id] == '100-MB' }

    self.credits = Website.cost_price_to_credits(plan[:cost_per_hour] * 24.0)
  end

  def verify_authentication(passwd)
    raise NotAuthorized, 'Not authorized' unless User.passwd_valid?(password_hash, passwd)
  end

  def collaborator_websites
    Collaborator.where(user: self).joins(:website).map(&:website)
  end

  def websites_with_access
    (websites + collaborator_websites).uniq
  end

  def redo_activation
    self.activated = false
    self.activation_hash = User.gen_activation_hash
  end

  def regen_api_token!
    self.token = SecureRandom.hex(16)
    save!
  end

  def regen_reset_token!
    self.reset_token = SecureRandom.hex(32)
    save!
  end

  def credits?(minimum_required_credits = 0)
    credits >= minimum_required_credits
  end

  def orders?
    orders.count.positive?
  end

  def can_create_new_website?
    orders.count.positive? || websites.count.zero?
  end

  def can?(action, website)
    assert Website::PERMISSIONS.include?(action)

    # admin can do everything
    return true if admin?

    # website owner can do everything
    return true if self == website.user

    collaborator = Collaborator.find_by(user: self, website: website)

    if !collaborator || !collaborator.permission?(action)
      raise Forbidden, 'Cannot access this resource'
    end

    true
  end

  def verify_email!
    return false if user_email_verifications.last

    verification = UserEmailVerification.create(ref_id: id)
    client = NeverBounce::API::Client.new(api_key: ENV["NEVER_BOUNCE_API_KEY"])

    response = client.single_check(email: email)

    verification.obj = response.touch
    verification.save

    is_valid = response.result == "valid"

    self.activated = is_valid
    save

    is_valid
  rescue StandardError => e
    logger.error("invalid email!")
    logger.error(e.inspect.to_s)

    false
  end

  def first_unused_coupon
    return nil unless coupons

    ucoupon = coupons.find { |coupon| !coupon['used'] }

    ucoupon ? Coupon.find_by(str_id: ucoupon['str_id']) : nil
  end

  def use_coupon!(coupon)
    return unless coupon

    self.coupons ||= []
    coupon_obj = JSON.parse(coupon.to_json)
    coupon_obj['used'] = true
    self.coupons << coupon_obj

    save
  end
end
