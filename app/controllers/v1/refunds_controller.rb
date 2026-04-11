module V1
  class RefundsController < ApplicationController
    include AuthenticateRequest

    # POST /v1/charges/:charge_id/refunds
    def create
      charge = current_merchant.charges.find_by!(id: params[:charge_id])

      result = RefundService.new(
        merchant: current_merchant,
        charge: charge,
        amount: refund_params[:amount].to_i,
        reason: refund_params[:reason]
      ).call

      render json: RefundBlueprint.render(result.refund), status: :created
    rescue ActiveRecord::RecordNotFound
      render_error(status: :not_found, code: "not_found", message: "Charge not found")
    rescue PaygateError => e
      render_error(status: e.status, code: e.code, message: e.message)
    end

    # GET /v1/charges/:charge_id/refunds
    def index
      charge = current_merchant.charges.find_by!(id: params[:charge_id])
      refunds = charge.refunds.recent

      render json: RefundBlueprint.render(refunds)
    rescue ActiveRecord::RecordNotFound
      render_error(status: :not_found, code: "not_found", message: "Charge not found")
    end

    # GET /v1/refunds/:id
    def show
      refund = current_merchant.refunds.find_by!(id: params[:id])
      render json: RefundBlueprint.render(refund)
    rescue ActiveRecord::RecordNotFound
      render_error(status: :not_found, code: "not_found", message: "Refund not found")
    end

    private

    def refund_params
      params.permit(:amount, :reason)
    end
  end
end
