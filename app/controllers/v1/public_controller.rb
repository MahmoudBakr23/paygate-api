module V1
  class PublicController < ApplicationController
    def sdk_config
      render json: {
        stripe_publishable_key: ENV.fetch("STRIPE_SANDBOX_PUBLISHABLE_KEY", nil),
        supported_methods: %w[card apple_pay mada],
        environment: "sandbox"
      }
    end
  end
end
