FactoryBot.define do
  factory :entity_id do
    association :merchant
    brand       { "card" }
    environment { "sandbox" }
    entity_id   { "8ac7a4ca#{SecureRandom.hex(8)}" }
  end
end
