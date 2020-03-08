class Collaborator < ApplicationRecord
  serialize :permissions, JSON

  belongs_to :website
  belongs_to :user

  validate :validate_permissions
  validate :validate_should_not_be_the_website_owner

  def validate_permissions
    self.permissions ||= []

    self.permissions = self.permissions.select { |p| Website::PERMISSIONS.include?(p) }

    if self.permissions.empty?
      errors.add(:permissions, "must have at least one")
    end

    if self.permissions.include?(Website::PERMISSION_ROOT) && self.permissions.length > 1
      errors.add(:permissions, "when root permission set it should not contain " \
                                "any other permission")
    end
  end

  def validate_should_not_be_the_website_owner
    if user == website.user
      errors.add(:user, "should not be the website owner")
    end
  end

  def permission?(perm)
    permissions.include?(Website::PERMISSION_ROOT) ||
      permissions.include?(perm)
  end
end
