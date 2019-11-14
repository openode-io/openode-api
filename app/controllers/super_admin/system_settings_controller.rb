class SuperAdmin::SystemSettingsController < SuperAdmin::SuperAdminController
  def save
    sys_setting = SystemSetting.find_or_create_by name: params["name"]
    sys_setting.content = params["content"]
    sys_setting.save

    json(sys_setting)
  end
end
