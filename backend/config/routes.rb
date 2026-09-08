Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      resources :merchants, except: %i[new edit]
      resources :menu_items, except: %i[new edit]
      resources :tags, except: %i[new edit]
      resources :business_hours, except: %i[new edit]
      resources :loyalty_rules, except: %i[new edit]
      resources :visit_summaries, except: %i[new edit]
      resources :visits, except: %i[new edit]
      resources :favorites, except: %i[new edit]
      resources :gifts, except: %i[new edit]
      resources :consumer_settings, except: %i[new edit]
      # The `search_history` table name is singular (see
      # app/models/search_history.rb), but the route/controller follow the
      # standard Rails plural resource convention.
      resources :search_histories, except: %i[new edit]
    end
  end

  # Defines the root path route ("/")
  # root "posts#index"
end
