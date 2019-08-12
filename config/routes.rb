Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  resources :instances do
    get '/', to: 'instances#show'
    get '/test', to: 'instances#test'
  end

end
