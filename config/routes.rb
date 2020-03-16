# frozen_string_literal: true

Rails.application.routes.draw do
  apipie

  get '/', to: 'global#test'

  namespace :super_admin do
    # post 'system_settings/save'
    post 'support/contact'

    # Order
    get 'orders', to: 'orders#index'
    post 'orders', to: 'orders#create'

    get 'users', to: 'users#index'

    get 'websites', to: 'websites#index'
    post 'websites/:id/update_open_source_request',
         to: 'websites#update_open_source_request'

    get 'newsletters', to: 'newsletters#index'
    post 'newsletters', to: 'newsletters#create'
    post 'newsletters/:id/send', to: 'newsletters#deliver'
  end

  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  mount ActionCable.server => '/streams'

  scope :account do
    post 'getToken', to: 'account#get_token'
    get  'me', to: 'account#me'
    patch 'me', to: 'account#update'
    post 'regenerate-token', to: 'account#regenerate_token'
    post 'register', to: 'account#register'
    post 'forgot-password', to: 'account#forgot_password'
    post 'verify-reset-token', to: 'account#verify_reset_token'
    get 'spendings', to: 'account#spendings'
    post 'activate/:user_id/:activation_hash', to: 'account#activate'
  end

  scope :billing do
    get  'orders', to: 'billing#orders'
  end

  scope :notifications do
    get '',         to: 'user_notifications#index'
    post 'view',    to: 'user_notifications#mark_viewed'
    get 'all',      to: 'notifications#index'
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
    patch '/:site_name/', to: 'instances#update'
    delete '/:site_name/', to: 'instances#destroy'

    get '/:site_name/stats', to: 'instance_stat#index'
    get '/:site_name/stats/spendings', to: 'instance_stat#spendings'

    get '/:site_name/get-config', to: 'configs#get_config'
    post '/:site_name/set-config', to: 'configs#set_config'

    get '/:site_name/locations', to: 'locations#index'
    post '/:site_name/add-location', to: 'locations#add_location'
    post '/:site_name/remove-location', to: 'locations#remove_location'

    get '/:site_name/docker-compose', to: 'instances#docker_compose' # to deprecate

    post '/:site_name/add-alias', to: 'dns#add_alias'
    post '/:site_name/del-alias', to: 'dns#del_alias'

    get '/:site_name/list-dns', to: 'dns#list_dns'  # to deprecate
    post '/:site_name/add-dns', to: 'dns#add_dns'   # to deprecate
    delete '/:site_name/del-dns', to: 'dns#del_dns' # to deprecate
    get '/:site_name/dns', to: 'dns#settings'

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

    get '/:site_name/storage', to: 'storages#retrieve'
    post '/:site_name/increase-storage', to: 'storages#increase'
    post '/:site_name/destroy-storage', to: 'storages#destroy'

    get '/:site_name/plan', to: 'instances#plan'
    get '/:site_name/plans', to: 'instances#plans'
    post '/:site_name/set-plan', to: 'instances#set_plan'

    # executions
    get '/:site_name/executions/list/:type', to: 'executions#index'
    get '/:site_name/executions/:id', to: 'executions#retrieve'

    # events
    get '/:site_name/events/', to: 'events#index'
    get '/:site_name/events/:id', to: 'events#retrieve'
  end
end
