module V1
  class ChargesController < ApplicationController
    include AuthenticateRequest

    def create
      idempotency_key = IdempotencyService.require_key!(request)

      result = ChargeService.new(
        merchant: current_merchant,
        idempotency_key: idempotency_key,
        amount: charge_params[:amount].to_i,
        currency: charge_params.fetch(:currency, "SAR"),
        payment_method: charge_params[:payment_method],
        token: charge_params[:token],
        metadata: charge_params[:metadata]&.to_unsafe_h || {}
      ).call

      status_code = result.replayed ? :ok : :created
      render json: ChargeBlueprint.render(result.charge), status: status_code
    rescue PaygateError => e
      render_error(status: e.status, code: e.code, message: e.message)
    end

    def show
      charge = current_merchant.charges.find_by!(id: params[:id])
      render json: ChargeBlueprint.render(charge)
    rescue ActiveRecord::RecordNotFound
      render_error(status: :not_found, code: "not_found", message: "Charge not found")
    end

    def index
      charges = current_merchant.charges
                                .for_environment(current_merchant.environment)
                                .recent

      charges = charges.where(status: params[:status])          if params[:status].present?
      charges = charges.where(payment_method: params[:method])  if params[:method].present?

      if params[:from].present? && params[:to].present?
        charges = charges.where(created_at: params[:from]..params[:to])
      end

      render json: ChargeBlueprint.render(charges)
    end

    private

    def charge_params
      params.permit(:amount, :currency, :payment_method, :token, metadata: {})
    end
  end
end
