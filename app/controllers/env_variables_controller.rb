class EnvVariablesController < InstancesController
  before_action do
    requires_access_to(Website::PERMISSION_CONFIG)
  end

  api :GET, 'instances/:id/env_variables'
  description 'Returns key-value environment variables.'
  def index
    json(@website.env)
  end

  api :PUT, 'instances/:id/env_variables'
  description 'Update environment variables ({ key:value }). ' \
              'Existing variables not provided in the hash are removed.'
  param :variables, Hash, desc: "Key-value hash of variables.", required: false
  def overwrite_env_variables
    variables = params[:variables]

    @website_event_obj = {
      title: "ENV Variables changed",
      variables: variables
    }
    @website.overwrite_env_variables!(variables)

    json({})
  end

  api :POST, 'instances/:id/env_variables'
  description 'Update environment variables ({ key:value }). ' \
              'Existing variables not provided in the hash are unchanged.'
  param :variables, Hash, desc: "Key-value hash of variables.", required: true
  def update_env_variables
    variables = params[:variables].to_unsafe_h

    @website_event_obj = {
      title: "ENV Variables changed",
      variables: variables
    }
    @website.update_env_variables!(variables)

    json({})
  end

  api :POST, 'instances/:id/env_variables/:name'
  description 'Create or update a variable'
  param :value, String, desc: "Value of the given variable."
  returns code: 200, desc: ""
  def save_env_variable
    @website_event_obj = {
      title: "ENV Variable changed",
      variable: params[:name]
    }
    @website.store_env_variable!(params[:name], params[:value])

    json({})
  end

  api :DELETE, 'instances/:id/env_variables/:name'
  description 'Remove a variable'
  returns code: 200, desc: ""
  def destroy_env_variable
    @website_event_obj = {
      title: "ENV Variable removed",
      variable: params[:name]
    }
    @website.destroy_env_variable!(params[:name])

    json({})
  end
end
