class ChargeBlueprint < Blueprinter::Base
  identifier :id

  fields :amount, :currency, :payment_method, :status, :provider,
         :provider_charge_id, :idempotency_key, :metadata, :failure_code,
         :failure_message, :environment, :captured_at, :created_at, :updated_at

  field :merchant_id
end
