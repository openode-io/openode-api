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

  protected

end
