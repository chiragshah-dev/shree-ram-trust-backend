# Rails.application.routes.draw do
#   devise_for :users
#   # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

#   # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
#   # Can be used by load balancers and uptime monitors to verify that the app is live.
#   get "up" => "rails/health#show", as: :rails_health_check

#   # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
#   # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
#   # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

#   # Defines the root path route ("/")
#   # root "posts#index"
#   namespace :api do
#     namespace :v1 do
#       post   'login',  to: 'sessions#create'
#       delete 'logout', to: 'sessions#destroy'
#     end
#   end

#   # namespace :admin do
#   #   resources :users, except: [:show] do
#   #     member { patch :toggle_active }
#   #   end
#   # end


#   namespace :admin do
#     get "dashboard/index"
#     get 'dashboard', to: 'dashboard#index'
#     resources :users do
#       member { patch :toggle_active }
#     end

#   end
#   root "admin/dashboard#index"

# end


Rails.application.routes.draw do
  devise_for :users

  namespace :api do
    namespace :v1 do

      # Auth
      post   'login',  to: 'sessions#create'
      delete 'logout', to: 'sessions#destroy'

      namespace :mpin do
        post 'set',         to: '/api/v1/mpins#set_mpin'
        post 'verify',      to: '/api/v1/mpins#verify_mpin'
        put  'change',      to: '/api/v1/mpins#change_mpin'
      end

      namespace :passwords do
        post :forgot       # step 1 — send OTP
        post :verify_otp   # step 2 — verify OTP → get reset_token
        post :reset        # step 3 — set new password
      end

      # Users
      resources :users, only: [:index, :create, :show, :update, :destroy] do
        member { patch :toggle_active }
      end

      # Profile (singular — no :id needed, always current_user)
      resource :profile, only: [:show, :update] do
        patch :change_password, on: :collection
      end

      # Tasks
      resources :tasks, only: [:index, :create, :show, :update, :destroy] do
        collection { get :dashboard }
        member do
          patch :complete
          patch :update_status
        end
      end

      # Notifications
      resources :notifications, only: [:index] do
        collection do
          get   :unread_count
          patch :mark_all_read
        end
        member { patch :mark_read }
      end

      # Reports
      namespace :reports do
        get  :daily
        get  :my_daily
        post :custom
      end

    end
  end
  namespace :admin do
    get "dashboard/index"
    get 'dashboard', to: 'dashboard#index'
    resources :users do
      member { patch :toggle_active }
    end

  end
  root "admin/dashboard#index"
end
