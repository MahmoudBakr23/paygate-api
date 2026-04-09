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
          api_keys: {
            public_key: result.api_key_result.public_key,
            secret_key: result.api_key_result.secret_key
          },
          token: result.token
        }, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render_error(status: :unprocessable_entity, code: "validation_error", message: e.message)
      end
    end
  end
end
