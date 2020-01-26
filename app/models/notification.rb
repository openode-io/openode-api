class Notification < ApplicationRecord
  has_many :viewed_notifications, dependent: :destroy

  LEVEL_INFO = 'info'
  LEVEL_WARNING = 'warning'
  LEVEL_CRITICAL = 'critical'
  LEVEL_PRIORITY = 'priority'
  LEVEL_TYPES = [LEVEL_INFO, LEVEL_WARNING, LEVEL_CRITICAL, LEVEL_PRIORITY].freeze

  validates :level, inclusion: { in: LEVEL_TYPES }

  scope :of_level, lambda { |level|
    where(level: level)
  }

  def viewed_by?(user)
    ViewedNotification.exists?(notification: self, user: user)
  end

  def self.of_user(user, opts = {})
    user_website_ids = user.websites_with_access.pluck(:id)

    if opts[:website] && !user_website_ids.include?(opts[:website].to_i)
      raise ApplicationRecord::ValidationError,
            "User not authorized to access this website (#{opts[:website]}). " \
            "Authorized are: #{user_website_ids}"
    end

    website_ids = opts[:website] ? [opts[:website]] : user_website_ids

    types = opts[:types] || %w[GlobalNotification WebsiteNotification]

    base_criteria_notifications = Notification.where(type: types)

    base_criteria_notifications
      .where(website_id: nil)
      .or(base_criteria_notifications.where(website_id: website_ids))
  end
end
