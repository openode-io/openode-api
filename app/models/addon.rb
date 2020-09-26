class Addon < ApplicationRecord
  serialize :obj, JSON

  validates :name, presence: true
  validates :name, uniqueness: true
  validates :category, presence: true

  validates_format_of :name, with: /[a-z]+-?([a-z0-9])+/i

  before_validation :downcase_name
  validate :validate_persistence

  def downcase_name
    self.name = name.downcase
  end

  def obj_field?(field_name)
    obj&.dig(field_name)&.present?
  end

  def requires_persistence?
    field_name_req_persistence = "requires_persistence"
    obj_field?(field_name_req_persistence) && obj&.dig(field_name_req_persistence)
  end

  def validate_persistence
    return unless requires_persistence?

    errors.add(:obj, 'persistent path missing') unless obj_field?("persistent_path")

    unless obj&.dig("required_fields")&.include?("persistent_path")
      errors.add(:obj, 'persistent path missing in required fields')
    end
  end

  def as_json(options = {})
    options[:methods] = [:repository_root_file_url]
    super
  end

  def repository_root_file_url
    manager = CloudProvider::Manager.instance
    addons_repository_fileroot_url = manager.application.dig(
      'addons', 'repository_fileroot_url'
    )

    "#{addons_repository_fileroot_url}#{category}/#{name}"
  end
end
