class Addon < ApplicationRecord
  serialize :obj, JSON

  validates :name, presence: true
  validates :name, uniqueness: true
  validates :category, presence: true

  validates_format_of :name, with: /[a-z]+-?([a-z0-9])+/i

  before_validation :downcase_name

  def downcase_name
    self.name = name.downcase
  end

  def obj_field?(field_name)
    obj&.dig(field_name)&.present?
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
