module V1
  class ApiKeysController < ApplicationController
    include AuthenticateRequest

    def index
      api_keys = current_merchant.api_keys.active.order(created_at: :desc)
      render json: ApiKeyBlueprint.render(api_keys)
    end

    def create
      environment = params.fetch(:environment, "sandbox")
      unless ApiKey::ENVIRONMENTS.include?(environment)
        return render_error(
          status: :unprocessable_content,
          code: "invalid_environment",
          message: "environment must be one of: #{ApiKey::ENVIRONMENTS.join(', ')}"
        )
      end

      result = ApiKeyService.new(merchant: current_merchant).generate_pair(environment: environment)

      render json: {
        api_key: ApiKeyBlueprint.render_as_hash(result.api_key),
        public_key: result.public_key,
        secret_key: result.secret_key
      }, status: :created
    end

    def destroy
      api_key = current_merchant.api_keys.active.find(params[:id])
      ApiKeyService.new(merchant: current_merchant).revoke(api_key: api_key)
      render json: { message: "API key revoked" }
    rescue ActiveRecord::RecordNotFound
      render_error(status: :not_found, code: "not_found", message: "API key not found")
    end
  end
end
