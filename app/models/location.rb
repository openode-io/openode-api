class Location < ApplicationRecord

  has_many :location_servers

  validates :str_id, uniqueness: true
  validates_inclusion_of :cloud_provider, :in => %w( internal vultr )

  SUBDOMAIN = {
    canada: '',
    france: 'fr',
    usa: 'us'
  }

end
