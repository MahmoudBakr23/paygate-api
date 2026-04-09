require "rails_helper"

RSpec.describe "POST /v1/auth/register" do
  let(:valid_params) do
    { name: "Acme Corp", email: "acme@example.com", password: "Password1!" }
  end

  it "creates a merchant and returns 201 with token and sandbox keys" do
    post "/v1/auth/register", params: valid_params, as: :json

    expect(response).to have_http_status(:created)
    expect(json_response[:token]).to be_present
    expect(json_response[:merchant][:email]).to eq("acme@example.com")
    expect(json_response[:api_keys][:public_key]).to start_with("pk_test_")
    expect(json_response[:api_keys][:secret_key]).to start_with("sk_test_")
  end

  it "returns 422 on duplicate email" do
    create(:merchant, email: "acme@example.com")
    post "/v1/auth/register", params: valid_params, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(json_response[:error][:code]).to eq("validation_error")
  end

  it "returns 422 on missing name" do
    post "/v1/auth/register", params: valid_params.except(:name), as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "returns 422 on invalid email format" do
    post "/v1/auth/register", params: valid_params.merge(email: "notanemail"), as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end
end
