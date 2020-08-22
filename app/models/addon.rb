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
end
