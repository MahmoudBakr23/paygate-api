module V1
  class WebhookEndpointsController < ApplicationController
    include AuthenticateRequest

    def index
      endpoints = current_merchant.webhook_endpoints.order(created_at: :desc)
      render json: WebhookEndpointBlueprint.render(endpoints)
    end

    def create
      endpoint = current_merchant.webhook_endpoints.build(webhook_endpoint_params)
      endpoint.save!
      render json: webhook_endpoint_response(endpoint), status: :created
    rescue ActiveRecord::RecordInvalid => e
      render_error(status: :unprocessable_content, code: "validation_error", message: e.message)
    end

    def update
      endpoint = current_merchant.webhook_endpoints.find(params[:id])
      endpoint.update!(webhook_endpoint_params)
      render json: WebhookEndpointBlueprint.render(endpoint)
    rescue ActiveRecord::RecordNotFound
      render_error(status: :not_found, code: "not_found", message: "Webhook endpoint not found")
    rescue ActiveRecord::RecordInvalid => e
      render_error(status: :unprocessable_content, code: "validation_error", message: e.message)
    end

    def destroy
      endpoint = current_merchant.webhook_endpoints.find(params[:id])
      endpoint.destroy!
      render json: { message: "Webhook endpoint removed" }
    rescue ActiveRecord::RecordNotFound
      render_error(status: :not_found, code: "not_found", message: "Webhook endpoint not found")
    end

    private

    def webhook_endpoint_params
      params.permit(:url, :active, events: [])
    end

    # Show webhook_secret once on creation; never again
    def webhook_endpoint_response(endpoint)
      {
        webhook_endpoint: WebhookEndpointBlueprint.render_as_hash(endpoint),
        webhook_secret: endpoint.webhook_secret
      }
    end
  end
end
