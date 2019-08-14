class Location < ApplicationRecord

  has_many :location_servers

  SUBDOMAIN = {
    canada: '',
    france: 'fr',
    usa: 'us'
  }

end
