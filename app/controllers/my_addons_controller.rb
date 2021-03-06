
class MyAddonsController < InstancesController
  before_action do
    requires_access_to(Website::PERMISSION_CONFIG)
  end

  before_action do
    if params['id']
      @website_addon = @website.website_addons.find_by! id: params['id']
    end
  end

  before_action only: %i[delete_addon update_addon] do
    requires_status_in [Website::STATUS_OFFLINE]
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
    deactivate_addon_storage(@website_addon)

    @website_addon.destroy!

    @website_event_obj = { title: 'delete-addon', name: @website_addon.name }

    json({})
  end

  api :POST, 'instances/:sitename/addons/:id/offline'
  description 'Deactivate a website addon.'
  def set_addon_offline
    deactivate_addon_storage(@website_addon)

    @website_event_obj = { title: 'set-addon-offline', name: @website_addon.name }

    json({})
  end

  def deactivate_addon_storage(website_addon)
    website_addon.status = WebsiteAddon::STATUS_OFFLINE
    website_addon.save(validate: false)

    @runner.execute([
                      {
                        cmd_name: 'destroy_storage_cmd',
                        options: { website_addon: website_addon }
                      }
                    ])
  end

  def permitted_params
    params.require(:addon).permit(:addon_id, :account_type, :name, obj: {})
  end

  def permitted_update_params
    params.require(:addon).permit(:account_type, :name, :storage_gb, obj: {})
  end
end
