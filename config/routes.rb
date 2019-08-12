Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  scope :instances do
    get '/', to: 'instances#index'
    get '/:site_name/', to: 'instances#show'
  end

  scope :global do
    get 'available-configs', to: 'global#available_configs'
  end

end
