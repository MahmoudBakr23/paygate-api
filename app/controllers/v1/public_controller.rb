module V1
  class PublicController < ApplicationController
    def sdk_config
      public_key = params[:public_key].to_s.strip
      api_key = ApiKey.active.find_by(public_key: public_key)

      return render json: { error: "invalid_public_key", message: "Public key not found or revoked" }, status: :not_found unless api_key

      environment = api_key.environment
      stripe_key = environment == "live" ? ENV.fetch("STRIPE_LIVE_PUBLISHABLE_KEY", nil) : ENV.fetch("STRIPE_SANDBOX_PUBLISHABLE_KEY", nil)

      render json: {
        stripe_publishable_key: stripe_key,
        supported_methods: %w[card apple_pay mada],
        environment: environment
      }
    end
  end
end
