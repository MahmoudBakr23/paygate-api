# Receives inbound webhooks from payment providers (Stripe, Checkout.com).
# These endpoints are NOT authenticated with API keys — provider identity is
# verified via HMAC signature inside ProviderWebhookProcessorJob.
class WebhooksController < ActionController::API
  def stripe
    payload_json = request.body.read
    signature    = request.headers["Stripe-Signature"].to_s

    ProviderWebhookProcessorJob.perform_later("stripe", payload_json, signature)
    head :ok
  end

  def checkout
    payload_json = request.body.read
    signature    = request.headers["Cko-Signature"].to_s

    ProviderWebhookProcessorJob.perform_later("checkout", payload_json, signature)
    head :ok
  end
end
