require "rails_helper"

RSpec.describe "Api::V1::Sessions", type: :request do
  describe "POST /api/v1/sessions" do
    it "authenticates with valid credentials and returns a token" do
      consumer = create_consumer(email: "login@example.com", password: "correct-password")

      post "/api/v1/sessions", params: { email: "login@example.com", password: "correct-password" }

      expect(response).to have_http_status(:ok)
      expect(json_response["token"]).to be_present
      expect(json_response["consumer"]["id"]).to eq(consumer.id)
      expect(json_response["consumer"]).not_to have_key("password_hash")
      expect(JsonWebToken.decode(json_response["token"])[:sub]).to eq(consumer.id)
    end

    it "returns 401 with a generic message for a wrong password" do
      create_consumer(email: "login@example.com", password: "correct-password")

      post "/api/v1/sessions", params: { email: "login@example.com", password: "wrong-password" }

      expect(response).to have_http_status(:unauthorized)
      expect(json_response["error"]).to eq("Invalid email or password")
    end

    it "returns 401 with the same generic message for a non-existent email" do
      post "/api/v1/sessions", params: { email: "nobody@example.com", password: "whatever" }

      expect(response).to have_http_status(:unauthorized)
      expect(json_response["error"]).to eq("Invalid email or password")
    end

    it "returns 401 (not 500) when the stored password_hash isn't a valid bcrypt digest" do
      consumer = create_consumer(email: "legacy@example.com")
      # update_column bypasses has_secure_password's setter/validations —
      # simulates old seed/test data written before bcrypt was in place.
      consumer.update_column(:password_hash, "not-a-real-bcrypt-digest")

      post "/api/v1/sessions", params: { email: "legacy@example.com", password: "whatever" }

      expect(response).to have_http_status(:unauthorized)
      expect(json_response["error"]).to eq("Invalid email or password")
    end
  end
end
