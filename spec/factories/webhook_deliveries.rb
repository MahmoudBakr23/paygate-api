FactoryBot.define do
  factory :webhook_delivery do
    association :webhook_endpoint
    event_type { "charge.captured" }
    payload    { { id: SecureRandom.uuid, event_type: "charge.captured", created_at: Time.current.iso8601, data: {} } }
    status     { "pending" }
    attempts   { 0 }

    trait :delivered do
      status       { "delivered" }
      http_status  { 200 }
      attempts     { 1 }
      delivered_at { Time.current }
    end

    trait :retrying do
      status        { "retrying" }
      http_status   { 500 }
      attempts      { 1 }
      next_retry_at { 5.minutes.from_now }
    end

    trait :failed do
      status      { "failed" }
      http_status { 500 }
      attempts    { 5 }
    end
  end
end
