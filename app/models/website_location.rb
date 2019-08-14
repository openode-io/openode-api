class WebsiteLocation < ApplicationRecord
  belongs_to :website
  belongs_to :location
  belongs_to :location_server
end
