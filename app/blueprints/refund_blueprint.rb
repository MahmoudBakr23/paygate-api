class RefundBlueprint < Blueprinter::Base
  identifier :id

  fields :charge_id, :merchant_id, :amount, :reason, :status,
         :provider_refund_id, :created_at, :updated_at
end
