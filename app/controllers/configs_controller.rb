class ConfigsController < InstancesController
  before_action :extract_variable

  before_action only: %i[set_config] do
    requires_access_to(Website::PERMISSION_CONFIG)
  end

  api!
  def get_config
    json(
      result: 'success',
      value: @website.configs[@var_name]
    )
  end

  api!
  def set_config
    value = params['value']

    @website.configs ||= {}
    @website.configs[@var_name.to_s] = value

    @website.save!

    @website_event_obj = {
      title: "Config value changed - #{@var_name}",
      variable: @var_name,
      value: value
    }

    json(
      result: 'success',
      configs: @website.reload.configs
    )
  end

  private

  def extract_variable
    @var_name = params['variable']

    unless Website.valid_config_variable?(@var_name)
      msg = 'Invalid variable name, Run openode available-configs for the list of valid variables.'
      raise ApplicationRecord::ValidationError, msg
    end
  end
end
