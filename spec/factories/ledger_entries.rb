FactoryBot.define do
  factory :ledger_entry do
    association :merchant
    charge_id   { SecureRandom.uuid }
    refund_id   { nil }
    entry_type  { "debit" }
    amount      { 1000 }
    currency    { "SAR" }
    description { "Test ledger entry" }

    trait :credit do
      entry_type { "credit" }
    end
  end
end
