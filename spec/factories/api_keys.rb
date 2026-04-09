FactoryBot.define do
  factory :api_key do
    association :merchant
    environment { "sandbox" }

    transient do
      raw_secret { "sk_test_#{SecureRandom.alphanumeric(32).downcase}" }
    end

    public_key { "pk_test_#{SecureRandom.alphanumeric(32).downcase}" }
    secret_key_digest { BCrypt::Password.create(raw_secret) }
    key_prefix { raw_secret.first(20) }

    trait :live do
      environment { "live" }
      transient do
        raw_secret { "sk_live_#{SecureRandom.alphanumeric(32).downcase}" }
      end
      public_key { "pk_live_#{SecureRandom.alphanumeric(32).downcase}" }
    end

    trait :revoked do
      revoked_at { 1.hour.ago }
    end
  end
end
