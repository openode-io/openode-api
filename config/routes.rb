Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  scope :account do
    post 'getToken', to: 'account#get_token'
    post 'register', to: 'account#register'
  end

  scope :global do
    get 'available-configs', to: 'global#available_configs'
    get 'test', to: 'global#test'
  end

  scope :instances do
    get '/', to: 'instances#index'
    get '/:site_name/', to: 'instances#show'
  end

end
