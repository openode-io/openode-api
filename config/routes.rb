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
    get 'websites/:id', to: 'websites#retrieve'
    post 'websites/:id/update_open_source_request',
         to: 'websites#update_open_source_request'

    get 'newsletters', to: 'newsletters#index'
    post 'newsletters', to: 'newsletters#create'
    post 'newsletters/:id/send', to: 'newsletters#deliver'

    get 'stats/spendings', to: 'stats#spendings'
    get 'stats/generic_daily_stats', to: 'stats#generic_daily_stats'
    get 'stats/nb_online', to: 'stats#nb_online'
    get 'stats/system', to: 'stats#system_stats'

    get 'generic/:entity', to: 'super_admin#generic_index'
  end

  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  mount ActionCable.server => '/streams'

  scope :account do
    post 'getToken', to: 'account#get_token'
    get  'me', to: 'account#me'
    patch 'me', to: 'account#update'
    delete 'me', to: 'account#destroy'
    get  'friend-invites', to: 'account#friend_invites'
    post 'invite-friend', to: 'account#invite_friend'
    post 'regenerate-token', to: 'account#regenerate_token'
    post 'register', to: 'account#register'
    post 'forgot-password', to: 'account#forgot_password'
    post 'verify-reset-token', to: 'account#verify_reset_token'
    get 'spendings', to: 'account#spendings'
    post 'activate/:user_id/:activation_hash', to: 'account#activate'

    # subscriptions
    get '/subscriptions/', to: 'subscription#index'
    post '/subscriptions/:subscription_id/cancel', to: 'subscription#cancel'
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
    get 'status/job-queues', to: 'global#status_job_queues'

    get '/services/down', to: 'global#services_down'
    get '/services', to: 'global#services'

    get 'available-locations', to: 'available_locations#index'
    get 'available-locations/:str_id/ips', to: 'available_locations#ips'

    get 'available-configs', to: 'global#available_configs'
    get 'available-plans', to: 'global#available_plans'
    get 'available-plans-at/:type/:location_str_id', to: 'global#available_plans_at'

    get 'type-lists/:type', to: 'global#type_lists'

    get 'settings', to: 'global#settings'
    get 'stats', to: 'global#stats'

    get 'addons', to: 'addons#index'
  end

  scope :open_source_projects do
    get 'latest', to: 'open_source#latest'
  end

  scope :open_source_project, constraints: { site_name: %r{[^/]+} } do
    get ':site_name', to: 'open_source#project'
  end

  scope :order do
    post 'paypal', to: 'order#paypal'
    post 'paypal_subscription', to: 'order#paypal_subscription'
  end

  scope :instances, constraints: { site_name: %r{[^/]+} } do
    get '/', to: 'instances#index'
    get '/summary', to: 'instances#summary'
    post '/create/', to: 'instances#create_instance'
    get '/:site_name/', to: 'instances#show'
    patch '/:site_name/', to: 'instances#update'
    delete '/:site_name/', to: 'instances#destroy_instance'
    post '/:site_name/crontab', to: 'instances#update_crontab'
    get '/:site_name/status', to: 'instances#status'
    get '/:site_name/summary', to: 'instances#instance_summary'
    get '/:site_name/routes', to: 'instances#routes'

    get '/:site_name/stats', to: 'instance_stat#index'
    get '/:site_name/stats/spendings', to: 'instance_stat#spendings'
    get '/:site_name/stats/network', to: 'instance_stat#network'

    get '/:site_name/get-config', to: 'configs#get_config'
    post '/:site_name/set-config', to: 'configs#set_config'
    post '/:site_name/configs', to: 'configs#update_configs'

    get '/:site_name/locations', to: 'locations#index'
    post '/:site_name/add-location', to: 'locations#add_location'
    post '/:site_name/remove-location', to: 'locations#remove_location'

    get '/:site_name/docker-compose', to: 'instances#docker_compose' # to deprecate

    post '/:site_name/add-alias', to: 'dns#add_alias'
    post '/:site_name/del-alias', to: 'dns#del_alias'

    get '/:site_name/dns', to: 'dns#settings'

    post '/:site_name/changes', to: 'instances#changes'
    post '/:site_name/sendCompressedFile', to: 'instances#send_compressed_file'
    delete '/:site_name/deleteFiles', to: 'instances#delete_files'
    post '/:site_name/cmd', to: 'instances#cmd'
    post '/:site_name/stop', to: 'instances#stop'
    post '/:site_name/reload', to: 'instances#reload'
    post '/:site_name/scm-clone', to: 'instances#scm_clone'
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

    # ENV
    get '/:site_name/env_variables', to: 'env_variables#index'
    put '/:site_name/env_variables/', to: 'env_variables#overwrite_env_variables'
    post '/:site_name/env_variables/', to: 'env_variables#update_env_variables'
    post '/:site_name/env_variables/:name', to: 'env_variables#save_env_variable'
    delete '/:site_name/env_variables/:name', to: 'env_variables#destroy_env_variable'

    # Snapshots
    post '/:site_name/snapshots/', to: 'snapshots#create_snapshot'
    get '/:site_name/snapshots/', to: 'snapshots#index'
    get '/:site_name/snapshots/:id', to: 'snapshots#retrieve'

    # Addons
    get '/:site_name/addons/', to: 'my_addons#index'
    get '/:site_name/addons/:id', to: 'my_addons#retrieve'
    post '/:site_name/addons/', to: 'my_addons#create_addon'
    patch '/:site_name/addons/:id', to: 'my_addons#update_addon'
    post '/:site_name/addons/:id/offline', to: 'my_addons#set_addon_offline'
    delete '/:site_name/addons/:id', to: 'my_addons#delete_addon'

    # executions
    get '/:site_name/executions/list/:type', to: 'executions#index'
    get '/:site_name/executions/:id', to: 'executions#retrieve'

    # events
    get '/:site_name/events/', to: 'events#index'
    get '/:site_name/events/:id', to: 'events#retrieve'
  end
end
