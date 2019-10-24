class Location < ApplicationRecord
  has_many :location_servers

  validates :str_id, uniqueness: true
  validates :cloud_provider, inclusion: { in: %w[internal vultr] }

  SUBDOMAIN = {
    canada: '',
    france: 'fr',
    usa: 'us'
  }.freeze
end
