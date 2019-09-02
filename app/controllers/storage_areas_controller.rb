class StorageAreasController < InstancesController

  def index
    json_res(@website.storage_areas)
  end

  protected

end
