FactoryBot.define do
  factory :refund do
    association :merchant
    charge_id           { SecureRandom.uuid }
    amount              { 500 }
    reason              { "requested_by_customer" }
    status              { "succeeded" }
    provider_refund_id  { "re_#{SecureRandom.hex(12)}" }

    trait :pending do
      status             { "pending" }
      provider_refund_id { nil }
    end

    trait :failed do
      status             { "failed" }
      provider_refund_id { nil }
    end
  end
end
