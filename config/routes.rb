# frozen_string_literal: true

Rails.application.routes.draw do
  apipie

  get '/', to: 'global#test'

  namespace :super_admin do
    # post 'system_settings/save'
    post 'support/contact'
  end

  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  mount ActionCable.server => '/streams'

  scope :account do
    post 'getToken', to: 'account#get_token'
    post 'register', to: 'account#register'
    post 'forgot-password', to: 'account#forgot_password'
    post 'verify-reset-token', to: 'account#verify_reset_token'
  end

  scope :notifications do
    get '',         to: 'user_notifications#index'
    post 'view',    to: 'user_notifications#mark_viewed'
    post '',        to: 'notifications#create'
    patch ':id',    to: 'notifications#update'
    delete ':id',   to: 'notifications#destroy'
  end

  scope :global do
    get 'test', to: 'global#test'
    get 'version', to: 'global#version'

    get '/services/down', to: 'global#services_down'
    get '/services', to: 'global#services'

    get 'available-locations', to: 'global#available_locations'
    get 'available-configs', to: 'global#available_configs'
    get 'available-plans', to: 'global#available_plans'
    get 'available-plans-at/:type/:location_str_id', to: 'global#available_plans_at'

    get 'settings', to: 'global#settings'
    get 'stats', to: 'global#stats'
  end

  scope :open_source_projects do
    get 'latest', to: 'open_source#latest'
  end

  scope :open_source_project, constraints: { site_name: %r{[^/]+} } do
    get ':site_name', to: 'open_source#project'
  end

  scope :order do
    post 'paypal', to: 'order#paypal'
  end

  scope :instances, constraints: { site_name: %r{[^/]+} } do
    get '/', to: 'instances#index'
    get '/summary', to: 'instances#summary'
    post '/create/', to: 'instances#create_instance'
    get '/:site_name/', to: 'instances#show'
    delete '/:site_name/', to: 'instances#destroy'

    get '/:site_name/stats', to: 'instance_stat#index'

    get '/:site_name/get-config', to: 'configs#get_config'
    post '/:site_name/set-config', to: 'configs#set_config'

    get '/:site_name/locations', to: 'locations#index'
    post '/:site_name/add-location', to: 'locations#add_location'
    post '/:site_name/remove-location', to: 'locations#remove_location'

    get '/:site_name/docker-compose', to: 'instances#docker_compose'

    post '/:site_name/add-alias', to: 'dns#add_alias'
    post '/:site_name/del-alias', to: 'dns#del_alias'

    get '/:site_name/list-dns', to: 'dns#list_dns'
    post '/:site_name/add-dns', to: 'dns#add_dns'
    delete '/:site_name/del-dns', to: 'dns#del_dns'

    post '/:site_name/changes', to: 'instances#changes'
    post '/:site_name/sendCompressedFile', to: 'instances#send_compressed_file'
    delete '/:site_name/deleteFiles', to: 'instances#delete_files'
    post '/:site_name/cmd', to: 'instances#cmd'
    post '/:site_name/stop', to: 'instances#stop'
    post '/:site_name/reload', to: 'instances#reload'
    post '/:site_name/restart', to: 'instances#restart'
    get '/:site_name/logs', to: 'instances#logs'
    post '/:site_name/erase-all', to: 'instances#erase_all'

    get '/:site_name/storage-areas', to: 'storage_areas#index'
    post '/:site_name/add-storage-area', to: 'storage_areas#add_storage_area'
    post '/:site_name/del-storage-area', to: 'storage_areas#remove_storage_area' # to refactor

    get '/:site_name/collaborators', to: 'collaborators#index'
    post '/:site_name/collaborators', to: 'collaborators#create'
    delete '/:site_name/collaborators/:id', to: 'collaborators#destroy'
    patch '/:site_name/collaborators/:id', to: 'collaborators#update'

    post '/:site_name/increase-storage', to: 'storages#increase'
    post '/:site_name/destroy-storage', to: 'storages#destroy'

    get '/:site_name/plan', to: 'instances#plan'
    get '/:site_name/plans', to: 'instances#plans'
    post '/:site_name/set-plan', to: 'instances#set_plan'

    post '/:site_name/allocate', to: 'private_cloud#allocate'
    post '/:site_name/apply', to: 'private_cloud#apply'
    get '/:site_name/private-cloud-info', to: 'private_cloud#private_cloud_info'
  end
end
