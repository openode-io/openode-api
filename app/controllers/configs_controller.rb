class ConfigsController < InstancesController
  before_action only: %i[get_config set_config] do
    extract_variable
  end

  before_action only: %i[set_config update_configs] do
    requires_access_to(Website::PERMISSION_CONFIG)
  end

  api!
  def get_config
    validate_variable_name(@var_name)

    json(
      result: 'success',
      value: @website.configs[@var_name]
    )
  end

  api!
  def set_config
    value = params['value']

    change_config!(@var_name, value)

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

  api :POST, 'instances/:id/configs'
  description 'Update multiple configs.'
  param :configs, Hash, desc: "Key-value hash of configs.", required: true
  def update_configs
    variables = params[:configs].to_unsafe_h

    variables.keys.each do |variable|
      change_config!(variable, variables.dig(variable))
    end

    @website_event_obj = {
      title: "Config values changed - #{variables.keys.inspect}",
      variables: variables.inspect
    }

    json(
      result: 'success',
      configs: @website.reload.configs
    )
  end

  private

  def extract_variable
    @var_name = params['variable']
  end

  def change_config!(variable, value)
    validate_variable_name(variable)

    @website.configs ||= {}
    @website.configs[variable.to_s] = value

    @website.save!
  end

  def validate_variable_name(var_name)
    unless Website.valid_config_variable?(var_name)
      msg = 'Invalid variable name, Run openode available-configs for the list of valid variables.'
      raise ApplicationRecord::ValidationError, msg
    end
  end
end
