module V1
  class EntityIdsController < ApplicationController
    include AuthenticateRequest

    def index
      entity_ids = current_merchant.entity_ids.order(:brand)
      render json: EntityIdBlueprint.render(entity_ids)
    end

    def create
      entity_id = current_merchant.entity_ids.build(entity_id_params)
      entity_id.save!
      render json: EntityIdBlueprint.render(entity_id), status: :created
    rescue ActiveRecord::RecordInvalid => e
      render_error(status: :unprocessable_content, code: "validation_error", message: e.message)
    end

    def destroy
      entity_id = current_merchant.entity_ids.find(params[:id])
      entity_id.destroy!
      render json: { message: "Entity ID removed" }
    rescue ActiveRecord::RecordNotFound
      render_error(status: :not_found, code: "not_found", message: "Entity ID not found")
    end

    private

    def entity_id_params
      params.permit(:brand, :environment, :entity_id)
    end
  end
end
