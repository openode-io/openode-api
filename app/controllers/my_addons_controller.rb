
class MyAddonsController < InstancesController
  before_action do
    requires_access_to(Website::PERMISSION_CONFIG)
  end

  before_action do
    if params['id']
      @website_addon = @website.website_addons.find_by! id: params['id']
    end
  end

  api :GET, 'instances/:sitename/addons'
  description 'Returns the website addons'
  def index
    json(@website.website_addons.order(:name))
  end

  api :GET, 'instances/:sitename/addons/:id'
  description 'Returns a given website addon'
  def retrieve
    json(@website_addon)
  end

  api :POST, 'instances/:sitename/addons'
  description 'Add a website addon. body: { addon: { addon_id, account_type, name, obj } }'
  def create_addon
    a_params = permitted_params.merge('website_id' => @website.id)

    addon = @website.website_addons.create!(a_params)

    @website_event_obj = { title: 'create-addon', name: addon.name }

    json(addon)
  end

  api :PATCH, 'instances/:sitename/addons/:id'
  description 'Update a website addon. body: { addon: { account_type, name, obj } }'
  def update_addon
    @website_addon.update!(permitted_update_params)

    @website_event_obj = { title: 'update-addon', name: @website_addon.name }

    json(@website_addon)
  end

  api :DELETE, 'instances/:sitename/addons/:id'
  description 'Delete a website addon.'
  def delete_addon
    @website_addon.destroy!

    @website_event_obj = { title: 'delete-addon', name: @website_addon.name }

    json({})
  end

  def permitted_params
    params.require(:addon).permit(:addon_id, :account_type, :name, obj: {})
  end

  def permitted_update_params
    params.require(:addon).permit(:account_type, :name, obj: {})
  end
end
