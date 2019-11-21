class Location < ApplicationRecord
  has_many :location_servers
  has_many :website_locations

  validates :str_id, uniqueness: true
  validates :cloud_provider, inclusion: { in: %w[internal vultr] }

  SUBDOMAIN = {
    canada: '',
    france: 'fr',
    usa: 'us'
  }.freeze
end
