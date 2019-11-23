class Collaborator < ApplicationRecord
  serialize :permissions, JSON

  belongs_to :website
  belongs_to :user

  PERMISSION_ROOT = 'root' # all permissions
  PERMISSION_DEPLOY = 'deploy'
  PERMISSION_DNS = 'dns'
  PERMISSION_ALIAS = 'alias'
  PERMISSION_STORAGE_AREA = 'storage_area'
  PERMISSION_LOCATION = 'location'
  PERMISSION_PLAN = 'plan'
  PERMISSION_CONFIG = 'config'

  PERMISSIONS = [
    PERMISSION_ROOT,
    PERMISSION_DEPLOY,
    PERMISSION_DNS,
    PERMISSION_ALIAS,
    PERMISSION_STORAGE_AREA,
    PERMISSION_LOCATION,
    PERMISSION_PLAN,
    PERMISSION_CONFIG
  ].freeze

  validate :validate_permissions
  validate :validate_should_not_be_the_website_owner

  def validate_permissions
    self.permissions ||= []

    if self.permissions.empty?
      errors.add(:permissions, "must have at least one")
    end

    if self.permissions.include?(PERMISSION_ROOT) && self.permissions.length > 1
      errors.add(:permissions, "when root permission set it should not contain " \
                                "any other permission")
    end
  end

  def validate_should_not_be_the_website_owner
    if user == website.user
      errors.add(:user, "should not be the website owner")
    end
  end
end
