Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  mount ActionCable.server => '/streams'

  scope :account do
    post 'getToken', to: 'account#get_token'
    post 'register', to: 'account#register'
  end

  scope :global do
    get 'available-locations', to: 'global#available_locations'
    get 'available-configs', to: 'global#available_configs'
    get 'test', to: 'global#test'
  end

  scope :instances, :constraints => {:site_name => /[^\/]+/} do
    get '/', to: 'instances#index'
    get '/:site_name/', to: 'instances#show'
    get '/:site_name/get-config', to: 'configs#get_config'
    post '/:site_name/set-config', to: 'configs#set_config'
    get '/:site_name/list-dns', to: 'dns#list_dns'
    get '/:site_name/storage-areas', to: 'storage_areas#index'

    post '/:site_name/increase-storage', to: 'storages#increase_storage'
  end

end
