FactoryBot.define do
  factory :webhook_endpoint do
    association :merchant
    url     { "https://example.com/webhooks" }
    events  { %w[charge.captured charge.failed refund.created] }
    active  { true }
    webhook_secret { "whsec_#{SecureRandom.hex(24)}" }
  end
end
