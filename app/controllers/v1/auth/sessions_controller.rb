module V1
  module Auth
    class SessionsController < ApplicationController
      include AuthenticateRequest

      skip_before_action :authenticate!, only: [:create]

      def create
        result = AuthService.new.login(email: params[:email], password: params[:password])
        render json: {
          token: result.token,
          merchant: MerchantBlueprint.render_as_hash(result.merchant)
        }
      rescue AuthService::AuthenticationError => e
        render_error(status: :unauthorized, code: "invalid_credentials", message: e.message)
      end

      def destroy
        AuthService.new.revoke_token(jti: @current_jwt_jti, exp: @current_jwt_exp) if @current_jwt_jti
        render json: { message: "Logged out successfully" }
      end
    end
  end
end
