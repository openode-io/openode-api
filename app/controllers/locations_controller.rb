class LocationsController < InstancesController

  def index
    result = @website.locations
      .map do |location|
        {
          id: location.str_id,
          name: location.full_name,
        }
      end

    json(result)
  end

  def add
    str_id = params["str_id"]

    if @website.location_exists?(str_id)
      self.validation_error!("Location already added")
    end

    if @website.website_locations.length >= 1
      msg = "Multi location is not currently supported. " +
          "Make sure to delete your existing location before adding a new one."
      
      self.validation_error!(msg)
    end

    json({ result: "success" })
  end

  protected

end
