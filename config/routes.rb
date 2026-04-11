Rails.application.routes.draw do
  # Health — infrastructure endpoints, no namespace
  get "/health", to: "health#liveness"
  get "/v1/health/ready", to: "health#readiness"

  # Inbound provider webhooks — no auth (HMAC verified inside job) (Phase 4)
  post "/webhooks/stripe",   to: "webhooks#stripe"
  post "/webhooks/checkout", to: "webhooks#checkout"

  namespace :v1 do
    # Auth (Phase 1)
    namespace :auth do
      post :register, to: "registrations#create"
      post :login, to: "sessions#create"
      delete :logout, to: "sessions#destroy"
    end

    # Merchant self-service
    resource :me, only: %i[show update], controller: :merchants do
      resources :api_keys, only: %i[index create destroy]
      resources :webhook_endpoints, only: %i[index create update destroy]
      resources :entity_ids, only: %i[index create destroy]
      get :dashboard, to: "dashboard#show"
    end

    # Charges (Phase 2) + Refunds/Voids (Phase 3)
    resources :charges, only: %i[create show index] do
      member do
        post :capture
        post :void
      end
      resources :refunds, only: %i[create index]
    end

    # Standalone refund lookup (Phase 3)
    resources :refunds, only: %i[show]

    # Webhooks — merchant signature verification (Phase 4)
    post "/webhooks/verify", to: "webhooks#verify"

  end
end
