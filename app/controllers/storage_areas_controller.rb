class StorageAreasController < InstancesController

  def index
    json_res(@website.storage_areas)
  end

  def add
    storage_area = params["storage_area"]
    @website.add_storage_area(storage_area)
    @website.save!

    json_res({
      "result": "success",
      "storageAreas": @website.reload.storage_areas
    })
  end

  protected

end
