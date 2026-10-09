Rails.application.routes.draw do
  root 'pages#index'
  get 'erb' => 'pages#erb'

  get 'frame' => 'frames#show'
  get 'frame/content' => 'frames#content', as: :frame_content

  resources :items, only: [:index, :create]

  get 'redirect' => 'redirects#new'
  post 'redirect' => 'redirects#create'
  get 'redirected' => 'redirects#show'
end
