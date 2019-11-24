class StorageAreasController < InstancesController
  before_action only: %i[add_storage_area remove_storage_area] do
    requires_access_to(Website::PERMISSION_STORAGE_AREA)
  end

  def index
    json(@website.storage_areas)
  end

  def add_storage_area
    change('add')
  end

  def remove_storage_area
    change('remove')
  end

  protected

  def change(operation)
    storage_area = params['storage_area']
    @website.send "#{operation}_storage_area", storage_area
    @website.save!

    @website_event_obj = {
      title: "#{operation}-storage-area",
      path: storage_area
    }

    json(
      "result": 'success',
      "storageAreas": @website.reload.storage_areas
    )
  end
end
