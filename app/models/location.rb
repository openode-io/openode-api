class Location < ApplicationRecord
  has_many :location_servers
  has_many :website_locations

  validates_uniqueness_of :str_id, case_sensitive: true
  validates :cloud_provider, inclusion: { in: %w[internal vultr] }

  SUBDOMAIN = {
    canada: '',
    france: 'fr',
    usa: 'us'
  }.freeze
end
