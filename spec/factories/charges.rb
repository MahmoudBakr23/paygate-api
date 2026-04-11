FactoryBot.define do
  factory :charge do
    association :merchant
    amount          { 1000 }
    currency        { "SAR" }
    payment_method  { "card" }
    status          { "pending" }
    provider        { "stripe" }
    provider_charge_id { "pi_#{SecureRandom.hex(12)}" }
    idempotency_key { SecureRandom.uuid }
    metadata        { {} }
    environment     { "sandbox" }

    trait :authorized do
      status { "authorized" }
    end

    trait :captured do
      status      { "captured" }
      captured_at { Time.current }
    end

    trait :failed do
      status          { "failed" }
      failure_code    { "card_declined" }
      failure_message { "Your card was declined." }
    end

    trait :voided do
      status { "voided" }
    end

    trait :mada do
      payment_method { "mada" }
      provider       { "checkout" }
    end

    trait :apple_pay do
      payment_method { "apple_pay" }
      provider       { "stripe" }
    end
  end
end
