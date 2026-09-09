require "rails_helper"

# Exercises Authenticatable's edge cases directly through a protected
# endpoint (GET /api/v1/favorites requires authenticate_consumer! on every
# action). All failure modes must land on 401 "Not authenticated" —
# never a 400/500 leaking internals.
RSpec.describe "Authentication", type: :request do
  describe "authenticate_consumer!" do
    it "returns 401 without an Authorization header" do
      get "/api/v1/favorites"

      expect(response).to have_http_status(:unauthorized)
      expect(json_response["error"]).to eq("Not authenticated")
    end

    it "returns 401 for a malformed bearer token" do
      get "/api/v1/favorites", headers: { "Authorization" => "Bearer not-a-jwt" }

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 for an expired token" do
      consumer = create_consumer
      expired_token = JsonWebToken.encode({ sub: consumer.id }, 1.hour.ago)

      get "/api/v1/favorites", headers: { "Authorization" => "Bearer #{expired_token}" }

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 when the token's consumer no longer exists" do
      token = JsonWebToken.encode(sub: SecureRandom.uuid)

      get "/api/v1/favorites", headers: { "Authorization" => "Bearer #{token}" }

      expect(response).to have_http_status(:unauthorized)
    end

    # A validly-signed token can still carry a malformed `sub` (hand-forged,
    # or from an incompatible token format). Without a UUID format guard,
    # this reaches Postgres's uuid column directly and raises
    # ActiveRecord::StatementInvalid, which the base controller's rescue_from
    # turns into 400 — but a broken token must still be 401, not 400.
    it "returns 401 (not 400) for a validly-signed token with a non-UUID sub" do
      token = JsonWebToken.encode(sub: "not-a-uuid")

      get "/api/v1/favorites", headers: { "Authorization" => "Bearer #{token}" }

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
