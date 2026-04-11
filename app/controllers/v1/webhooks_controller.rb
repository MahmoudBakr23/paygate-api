module V1
  # Utility endpoint: merchants can verify that a webhook payload and its
  # X-PayGate-Signature header were genuinely signed by Paygate.
  class WebhooksController < ApplicationController
    include AuthenticateRequest

    def verify
      endpoint = current_merchant.webhook_endpoints.find_by(id: params[:endpoint_id])

      unless endpoint
        return render_error(
          status: :not_found,
          code: "not_found",
          message: "Webhook endpoint not found"
        )
      end

      raw_payload = params[:payload].to_s
      signature   = params[:signature].to_s.delete_prefix("sha256=")
      expected    = OpenSSL::HMAC.hexdigest("SHA256", endpoint.webhook_secret, raw_payload)
      valid       = ActiveSupport::SecurityUtils.secure_compare(expected, signature)

      render json: { valid: valid }
    end
  end
end
