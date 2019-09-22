Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  mount ActionCable.server => '/streams'

  scope :account do
    post 'getToken', to: 'account#get_token'
    post 'register', to: 'account#register'
  end

  scope :global do
    get 'test', to: 'global#test'
    get 'version', to: 'global#version'

    get '/services/down', to: 'global#services_down'
    get '/services', to: 'global#services'

    get 'available-locations', to: 'global#available_locations'
    get 'available-configs', to: 'global#available_configs'
  end

  scope :instances, :constraints => {:site_name => /[^\/]+/} do
    get '/', to: 'instances#index'
    get '/:site_name/', to: 'instances#show'

    get '/:site_name/get-config', to: 'configs#get_config'
    post '/:site_name/set-config', to: 'configs#set_config'

    get '/:site_name/locations', to: 'locations#index'

    get '/:site_name/docker-compose', to: 'instances#docker_compose'

    get '/:site_name/list-dns', to: 'dns#list_dns'

    post '/:site_name/changes', to: 'instances#changes'
    post '/:site_name/sendCompressedFile', to: 'instances#send_compressed_file'
    delete '/:site_name/deleteFiles', to: 'instances#delete_files'
    post '/:site_name/restart', to: 'instances#restart'
    get '/:site_name/logs', to: 'instances#logs'
    post '/:site_name/erase-all', to: 'instances#erase_all'

    get '/:site_name/storage-areas', to: 'storage_areas#index'
    post '/:site_name/add-storage-area', to: 'storage_areas#add'
    post '/:site_name/del-storage-area', to: 'storage_areas#remove' # todo refactor

    get '/:site_name/snapshots/:id', to: 'snapshots#show'
    post '/:site_name/snapshots/create', to: 'snapshots#create'

    post '/:site_name/increase-storage', to: 'storages#increase'
    post '/:site_name/decrease-storage', to: 'storages#decrease'
  end

end
