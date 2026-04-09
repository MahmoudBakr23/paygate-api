class ApiKeyBlueprint < Blueprinter::Base
  identifier :id

  fields :environment, :public_key, :last_used_at, :revoked_at, :created_at
end
