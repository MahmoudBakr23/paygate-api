module V1
  class MerchantsController < ApplicationController
    include AuthenticateRequest

    def show
      render json: MerchantBlueprint.render(current_merchant)
    end

    def update
      current_merchant.update!(merchant_params)
      render json: MerchantBlueprint.render(current_merchant)
    rescue ActiveRecord::RecordInvalid => e
      render_error(status: :unprocessable_entity, code: "validation_error", message: e.message)
    end

    private

    def merchant_params
      params.permit(:name, :webhook_url, enabled_payment_methods: [])
    end
  end
end
