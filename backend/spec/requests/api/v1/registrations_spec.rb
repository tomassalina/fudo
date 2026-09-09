require "rails_helper"

RSpec.describe "Api::V1::Registrations", type: :request do
  describe "POST /api/v1/registrations" do
    let(:valid_attrs) do
      {
        email: "new-consumer@example.com", password: "password123", password_confirmation: "password123",
        first_name: "Ada", last_name: "Lovelace", dni: SecureRandom.random_number(10**8).to_s
      }
    end

    it "creates a consumer and returns it with a token" do
      post "/api/v1/registrations", params: { registration: valid_attrs }

      expect(response).to have_http_status(:created)
      expect(json_response["token"]).to be_present
      expect(json_response["consumer"]["email"]).to eq(valid_attrs[:email])
      expect(json_response["consumer"]).not_to have_key("password_hash")
      expect(json_response["consumer"]).not_to have_key("dni")
    end

    it "creates a consumer without a dni (loaded later by the waiter at checkout, not at registration)" do
      post "/api/v1/registrations", params: { registration: valid_attrs.except(:dni) }

      expect(response).to have_http_status(:created)
      expect(json_response["token"]).to be_present
      consumer = Consumer.find(json_response["consumer"]["id"])
      expect(consumer.dni).to be_nil
    end

    it "allows multiple consumers to register without a dni" do
      post "/api/v1/registrations", params: { registration: valid_attrs.except(:dni) }
      expect(response).to have_http_status(:created)

      post "/api/v1/registrations",
        params: { registration: valid_attrs.except(:dni).merge(email: "another-consumer@example.com") }
      expect(response).to have_http_status(:created)
    end

    it "stamps the new consumer as its own created_by (self-registration)" do
      post "/api/v1/registrations", params: { registration: valid_attrs }

      consumer = Consumer.find(json_response["consumer"]["id"])
      expect(consumer.created_by).to eq(consumer.id)
    end

    it "issues a token that authenticates as the new consumer" do
      post "/api/v1/registrations", params: { registration: valid_attrs }
      token = json_response["token"]
      consumer_id = json_response["consumer"]["id"]

      get "/api/v1/favorites", headers: { "Authorization" => "Bearer #{token}" }

      expect(response).to have_http_status(:ok)
      expect(JsonWebToken.decode(token)[:sub]).to eq(consumer_id)
    end

    it "returns 422 for a duplicate email" do
      create_consumer(email: "duplicate@example.com")

      post "/api/v1/registrations", params: { registration: valid_attrs.merge(email: "duplicate@example.com") }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response["errors"]).to have_key("email")
    end

    it "returns 422 for a duplicate dni" do
      existing = create_consumer

      post "/api/v1/registrations", params: { registration: valid_attrs.merge(dni: existing.dni) }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response["errors"]).to have_key("dni")
    end

    it "returns 422 when password confirmation doesn't match" do
      post "/api/v1/registrations",
        params: { registration: valid_attrs.merge(password_confirmation: "something-else") }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response["errors"]).to have_key("password_confirmation")
    end

    it "returns 422 when required fields are missing" do
      post "/api/v1/registrations", params: { registration: valid_attrs.merge(first_name: nil) }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response["errors"]).to have_key("first_name")
    end
  end
end
