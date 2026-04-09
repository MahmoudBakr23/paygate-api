class MerchantBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :email, :environment, :enabled_payment_methods, :webhook_url, :created_at, :updated_at
end
