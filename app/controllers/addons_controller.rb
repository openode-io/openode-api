
class AddonsController < ApplicationController
  api!
  def index
    json(Addon.order(:name))
  end
end
