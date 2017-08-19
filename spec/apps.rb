module Blog
  class Engine < ::Rails::Engine
    isolate_namespace Blog
    routes.draw do
      get "/articles", to: "articles#index"
    end
  end
end

module Main
  class Application < Rails::Application
    routes.draw do
      mount Blog::Engine, at: '/blog'
      namespace :api do
        namespace :v1 do
          get 'ignored', to: 'ignored#index'
          resources :sample, except: [:create, :update] do
            get 'ignored' # an action without documentation should not cause any errors
          end
          patch 'sample', to: 'sample#create' unless Rails::VERSION::MAJOR == 3 # intentional duplicate of above route to ensure PATCH is used
          put 'sample', to: 'sample#create'
          put 'sample/:id', to: 'sample#update'
          get 'context_dependent', to: 'sample#context_dependent'
          resources :nested, only: [] do
            get 'nested_sample', to: 'nested#index'
          end
          get 'custom_resource_path/:custom_resource_path/custom_resource_path_sample', to: 'custom_resource_path#index'
          match 'multiple_routes', to: 'multiple_routes#index', via: [:get, :post]
        end
      end
    end
  end
end
