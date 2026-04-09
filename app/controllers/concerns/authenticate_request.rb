module AuthenticateRequest
  extend ActiveSupport::Concern

  included do
    before_action :authenticate!
  end

  private

  def authenticate!
    raw_token = extract_bearer_token
    return render_unauthorized("Missing Authorization header") if raw_token.blank?

    if raw_token.start_with?("sk_test_", "sk_live_")
      authenticate_via_api_key!(raw_token)
    else
      authenticate_via_jwt!(raw_token)
    end
  end

  def authenticate_via_api_key!(raw_key)
    api_key = ApiKeyService.authenticate(raw_key: raw_key)
    return render_unauthorized("Invalid or revoked API key") unless api_key

    @current_merchant = api_key.merchant
    @current_api_key = api_key
  end

  def authenticate_via_jwt!(token)
    result = AuthService.new.verify_token(token: token)
    @current_merchant = result.merchant
    @current_jwt_jti = result.jti
    @current_jwt_exp = result.exp
  rescue AuthService::InvalidTokenError => e
    render_unauthorized(e.message)
  end

  def extract_bearer_token
    header = request.headers["Authorization"]
    return nil unless header&.start_with?("Bearer ")

    header.split(" ", 2).last
  end

  def current_merchant
    @current_merchant
  end

  def current_api_key
    @current_api_key
  end

  def render_unauthorized(message)
    render json: { error: { code: "unauthorized", message: message } }, status: :unauthorized
  end
end
