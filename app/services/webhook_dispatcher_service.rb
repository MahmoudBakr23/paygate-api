class WebhookDispatcherService
  def self.dispatch(event_type:, charge: nil, refund: nil, merchant:)
    new(event_type: event_type, charge: charge, refund: refund, merchant: merchant).dispatch
  end

  def initialize(event_type:, charge:, refund:, merchant:)
    @event_type = event_type
    @charge     = charge
    @refund     = refund
    @merchant   = merchant
  end

  def dispatch
    endpoints = WebhookEndpoint.where(merchant: @merchant).subscribed_to(@event_type)
    return if endpoints.none?

    payload = build_payload
    endpoints.each { |ep| enqueue_delivery(ep, payload) }
  end

  private

  def build_payload
    {
      id: SecureRandom.uuid,
      event_type: @event_type,
      created_at: Time.current.iso8601,
      data: event_data
    }
  end

  def event_data
    if @refund
      {
        object: "refund",
        refund: refund_data,
        charge: charge_data(@charge)
      }
    else
      {
        object: "charge",
        charge: charge_data(@charge)
      }
    end
  end

  def charge_data(charge)
    return nil unless charge

    {
      id: charge.id,
      amount: charge.amount,
      currency: charge.currency,
      status: charge.status,
      payment_method: charge.payment_method,
      provider: charge.provider,
      environment: charge.environment,
      created_at: charge.created_at.iso8601
    }
  end

  def refund_data
    {
      id: @refund.id,
      amount: @refund.amount,
      currency: @charge&.currency,
      status: @refund.status,
      reason: @refund.reason,
      created_at: @refund.created_at.iso8601
    }
  end

  def enqueue_delivery(endpoint, payload)
    delivery = WebhookDelivery.create!(
      webhook_endpoint: endpoint,
      charge_id: @charge&.id,
      event_type: @event_type,
      payload: payload,
      status: "pending"
    )
    WebhookDeliveryJob.perform_later(delivery.id)
  end
end
