module V1
  class DashboardController < ApplicationController
    include AuthenticateRequest

    def show
      charges = current_merchant.charges

      total_volume = charges.where(status: "captured").sum(:amount)
      total_charges = charges.count
      captured_count = charges.where(status: "captured").count
      failed_count = charges.where(status: "failed").count
      refunded_count = charges.where(status: "refunded").count

      success_rate = total_charges.positive? ? (captured_count.to_f / total_charges * 100).round(2) : 0.0

      volume_by_method = charges.where(status: "captured")
                                .group(:payment_method)
                                .sum(:amount)

      render json: {
        total_volume: total_volume,
        currency: "SAR",
        total_charges: total_charges,
        captured_count: captured_count,
        failed_count: failed_count,
        refunded_count: refunded_count,
        success_rate: success_rate,
        volume_by_method: volume_by_method
      }
    end
  end
end
