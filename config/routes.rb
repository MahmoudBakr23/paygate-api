Rails.application.routes.draw do
  # Health — infrastructure endpoints, no namespace
  get "/health", to: "health#liveness"
  get "/v1/health/ready", to: "health#readiness"

  namespace :v1 do
    # Auth (Phase 1)
    # namespace :auth do
    #   post :register
    #   post :login
    #   post :logout
    # end

    # Charges (Phase 2)
    # resources :charges, only: %i[create show index] do
    #   member do
    #     post :capture
    #     post :void
    #   end
    #   resources :refunds, only: %i[create index]
    # end

    # Webhooks (Phase 4)
    # post "/webhooks/verify", to: "webhooks#verify"

    # Entity IDs (Phase 5)
    # resources :entity_ids, only: %i[index create destroy]

    # Merchant self-service (Phase 5)
    # resource :me, only: %i[show update], controller: :merchants do
    #   resources :api_keys, only: %i[index create destroy]
    #   resources :webhooks, only: %i[index create update destroy]
    #   get :dashboard
    # end
  end
end
