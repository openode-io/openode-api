class Website < ApplicationRecord

  self.inheritance_column = :_type

  belongs_to :user

  validates :site_name, presence: true
  validates :site_name, uniqueness: true
  validates :type, presence: true
  validates :domain_type, presence: true
  validates :cloud_type, presence: true

  enum type: [ :nodejs, :docker ]
  enum domain_type: [ :subdomain, :custom_domain ]
  enum cloud_type: [ :cloud, "private-cloud" ]
end
