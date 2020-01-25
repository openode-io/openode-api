class Notification < ApplicationRecord
  has_many :viewed_notifications

  LEVEL_INFO = 'info'
  LEVEL_WARNING = 'warning'
  LEVEL_CRITICAL = 'critical'
  LEVEL_PRIORITY = 'priority'
  LEVEL_TYPES = [LEVEL_INFO, LEVEL_WARNING, LEVEL_CRITICAL, LEVEL_PRIORITY].freeze

  validates :level, inclusion: { in: LEVEL_TYPES }

  scope :of_level, lambda { |level|
    where(level: level)
  }
end
