class WebhookDeliveryBlueprint < Blueprinter::Base
  identifier :id

  fields :event_type, :payload, :status, :http_status, :attempts,
         :next_retry_at, :delivered_at, :created_at

  field :webhook_endpoint_id
  field :charge_id
end
