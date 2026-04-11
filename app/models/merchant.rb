class Merchant < ApplicationRecord
  has_secure_password
  has_many :api_keys, dependent: :destroy
  has_many :charges, dependent: :destroy
  has_many :refunds, dependent: :destroy
  has_many :ledger_entries, dependent: :destroy

  ENVIRONMENTS = %w[sandbox live].freeze
  PAYMENT_METHODS = %w[card mada apple_pay].freeze

  validates :name, presence: true
  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :environment, inclusion: { in: ENVIRONMENTS }
  validates :enabled_payment_methods,
            inclusion: { in: PAYMENT_METHODS, message: "%{value} is not a valid payment method" },
            allow_blank: true

  before_save :downcase_email

  private

  def downcase_email
    self.email = email.downcase
  end
end
