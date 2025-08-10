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
      
      # Search endpoints
      resources :search, only: [] do
        collection do
          post :vector
          post :hybrid
          post :entities
          post :suggest
          get :analytics
          get :entity_counts

        end
      end
      
      # Embedding management endpoints
      resources :embeddings, only: [] do
        collection do
          post :generate
          post :batch_import
          get :status
        end
      end
      
      # Tile package endpoint
      get 'tiles/package.zip', to: 'tiles#package'
      
      # Infrastructure endpoints
      resources :infrastructures, only: [:index, :show], param: :id
      
      # MCP Server endpoints  
      match 'mcp/sse', to: 'mcp/mcp#sse', via: [:get, :post]
      post 'mcp/tools', to: 'mcp/mcp#tools'
      
      # Chat endpoints
      post 'chat', to: 'chat#create'
      post 'chat/responses', to: 'responses_chat#create' # New Responses API with MCP
      
      # Development-only theme editing
      if Rails.env.development?
        resources :themes, only: [:index, :create, :update, :destroy]
      end
      
      # Camp Management System - OKNOTOK 2025
      resources :theme_camps, param: :id do
        member do
          get :team  # GET /theme_camps/:slug/team
          get :map   # GET /theme_camps/:slug/map
        end
        
        # Nested team member resources
        resources :team_members, param: :id do
          # Personal space for each team member
          resource :personal_space, only: [:show, :create, :update, :destroy]
        end
        
        # Camp map and placements
        resource :map, controller: :camp_maps, only: [:show, :create, :update, :destroy] do
          member do
            get :stats
            post :placements, action: :add_placement
          end
        end
      end
      
      # GLTF 3D Models (global resource)
      resources :gltf_models do
        member do
          get :download
          get :preview
        end
        collection do
          get 'categories/:category', action: :by_category
        end
      end
    end
  end
  
  # Admin interface for infrastructure (development only)
  if Rails.env.development?
    namespace :admin do
      resources :infrastructures do
        resources :locations
        resources :timeline_events
        resources :facts
        resources :links
        resources :photos do
          member do
            patch :set_as_hero
          end
          collection do
            post :bulk_upload
          end
        end
      end
    end
  end

  # Legacy weather endpoints (keep for backward compatibility)
  get "weather", to: "weather#show"
  delete "weather/cache", to: "weather#clear_cache"
  
  # Chat interfaces
  get 'chat', to: 'chat#show'
  get 'chat/turbo', to: 'chat#turbo'
  get 'chat/simple', to: 'chat#simple'
  get 'chat/mcp', to: 'chat#mcp'

  # Defines the root path route ("/")
  # root "posts#index"
end
