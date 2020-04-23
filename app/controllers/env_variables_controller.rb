class EnvVariablesController < InstancesController
  before_action do
    requires_access_to(Website::PERMISSION_CONFIG)
  end

  api :GET, 'instances/:id/env_variables'
  description 'Returns key-value environment variables.'
  def index
    json(@website.env)
  end

  api :POST, 'instances/:id/env_variables/:name'
  description 'Create or update a variable'
  param :value, String, desc: "Value of the given variable."
  returns code: 200, desc: ""
  def save_env_variable
    @website.store_env_variable!(params[:name], params[:value])

    json({})
  end

  api :DELETE, 'instances/:id/env_variables/:name'
  description 'Remove a variable'
  returns code: 200, desc: ""
  def destroy_env_variable
    @website.destroy_env_variable!(params[:name])

    json({})
  end
end
