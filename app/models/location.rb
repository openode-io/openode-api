class Location < ApplicationRecord

  has_many :location_servers

  validates :str_id, uniqueness: true

  SUBDOMAIN = {
    canada: '',
    france: 'fr',
    usa: 'us'
  }

end
