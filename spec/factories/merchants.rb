FactoryBot.define do
  factory :merchant do
    name { Faker::Company.name }
    sequence(:email) { |n| "merchant#{n}@example.com" }
    password { "Password1!" }
    environment { "sandbox" }
    enabled_payment_methods { %w[card mada apple_pay] }
  end
end
