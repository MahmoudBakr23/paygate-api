class WebhookDeliveryJob < ApplicationJob
  queue_as :webhook_delivery

  # Sidekiq retry is disabled — we manage our own exponential backoff schedule
  # so the retry timeline (1m → 5m → 30m → 2h → 24h) is explicit and auditable.
  sidekiq_options retry: false

  def perform(delivery_id)
    delivery = WebhookDelivery.find_by(id: delivery_id)
    return unless delivery  # deleted or missing — nothing to do

    endpoint = delivery.webhook_endpoint
    return unless endpoint.active

    response = post_to_endpoint(endpoint, delivery)
    handle_response(delivery, response)
  rescue StandardError => e
    handle_failure(delivery, error_message: e.message)
  end

  private

  def post_to_endpoint(endpoint, delivery)
    payload_json = delivery.payload.to_json
    signature    = sign_payload(payload_json, endpoint.webhook_secret)

    uri = URI.parse(endpoint.url)
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: 15) do |http|
      request = Net::HTTP::Post.new(uri.request_uri)
      request["Content-Type"]       = "application/json"
      request["X-PayGate-Signature"] = "sha256=#{signature}"
      request["X-PayGate-Event"]     = delivery.event_type
      request["X-PayGate-Delivery"]  = delivery.id
      request.body = payload_json
      http.request(request)
    end
  end

  def handle_response(delivery, response)
    http_status = response.code.to_i
    if http_status >= 200 && http_status < 300
      delivery.update!(
        status: "delivered",
        http_status: http_status,
        attempts: delivery.attempts + 1,
        delivered_at: Time.current
      )
    else
      handle_failure(delivery, http_status: http_status)
    end
  end

  def handle_failure(delivery, http_status: nil, error_message: nil)
    new_attempts = delivery.attempts + 1

    if new_attempts >= WebhookDelivery::MAX_ATTEMPTS
      delivery.update!(
        status: "failed",
        http_status: http_status,
        attempts: new_attempts
      )
      Rails.logger.warn(
        event: "webhook_delivery_failed",
        delivery_id: delivery.id,
        endpoint_id: delivery.webhook_endpoint_id,
        attempts: new_attempts,
        error: error_message
      )
    else
      delay = WebhookDelivery::RETRY_DELAYS[new_attempts - 1] || WebhookDelivery::RETRY_DELAYS.last
      retry_at = Time.current + delay

      delivery.update!(
        status: "retrying",
        http_status: http_status,
        attempts: new_attempts,
        next_retry_at: retry_at
      )
      self.class.set(wait_until: retry_at).perform_later(delivery.id)
    end
  end

  def sign_payload(payload_json, secret)
    OpenSSL::HMAC.hexdigest("SHA256", secret, payload_json)
  end
end
