Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # API v1 namespace
  namespace :api do
    namespace :v1 do
      # Weather endpoints
      post "weather/current", to: "weather#current"
      get "test", to: "weather#test"
    end
  end

  # Legacy weather endpoints (keep for backward compatibility)
  get "weather", to: "weather#show"
  delete "weather/cache", to: "weather#clear_cache"

  # Defines the root path route ("/")
  # root "posts#index"
end
