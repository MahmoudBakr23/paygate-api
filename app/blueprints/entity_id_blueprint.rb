class EntityIdBlueprint < Blueprinter::Base
  identifier :id

  fields :brand, :environment, :entity_id, :created_at

  field :merchant_id
end
