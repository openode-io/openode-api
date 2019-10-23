# frozen_string_literal: true

class StorageAreasController < InstancesController
  def index
    json(@website.storage_areas)
  end

  def add
    change('add')
  end

  def remove
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
