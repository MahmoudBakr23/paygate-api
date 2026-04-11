class EntityId < ApplicationRecord
  BRANDS = %w[card mada apple_pay].freeze
  ENVIRONMENTS = %w[sandbox live].freeze

  belongs_to :merchant

  validates :brand, inclusion: { in: BRANDS }
  validates :environment, inclusion: { in: ENVIRONMENTS }
  validates :entity_id, presence: true
  validates :brand, uniqueness: { scope: %i[merchant_id environment], message: "already configured for this environment" }
end
