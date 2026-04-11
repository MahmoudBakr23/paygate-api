module V1
  module Auth
    class RegistrationsController < ApplicationController
      def create
        result = AuthService.new.register(
          name: params[:name],
          email: params[:email],
          password: params[:password]
        )

        render json: {
          merchant: MerchantBlueprint.render_as_hash(result.merchant),
          token: result.token
        }, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render_error(status: :unprocessable_content, code: "validation_error", message: e.message)
      end
    end
  end
end
