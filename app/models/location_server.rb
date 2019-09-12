class LocationServer < ApplicationRecord

  attr_encrypted :password, key: ENV["SECRET_KEY_LOCATION_SERVERS"]

  belongs_to :location

end
