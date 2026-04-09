require "rails_helper"

RSpec.describe "Health endpoints", type: :request do
  describe "GET /health" do
    it "returns 200 with status ok" do
      get "/health"

      expect(response).to have_http_status(:ok)
      expect(json_response[:status]).to eq("ok")
    end

    it "responds even without an Authorization header" do
      get "/health"

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /v1/health/ready" do
    it "returns 200 when DB and Redis are reachable" do
      get "/v1/health/ready"

      expect(response).to have_http_status(:ok)
      expect(json_response[:status]).to eq("ok")
      expect(json_response[:checks][:db]).to be(true)
      expect(json_response[:checks][:redis]).to be(true)
    end
  end
end
