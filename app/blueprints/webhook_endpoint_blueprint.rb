class WebhookEndpointBlueprint < Blueprinter::Base
  identifier :id

  fields :url, :events, :active, :created_at

  field :merchant_id
end
