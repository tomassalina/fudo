require "rails_helper"

# Rack::Attack is disabled by default in the test suite (see
# spec/support/rack_attack.rb) to avoid flaky cross-spec throttling; the
# :rate_limited tag re-enables it just for these examples.
RSpec.describe "Rate limiting", type: :request, rate_limited: true do
  describe "POST /api/v1/sessions" do
    it "returns 429 once the login throttle limit is exceeded" do
      consumer = create_consumer

      5.times do
        post "/api/v1/sessions", params: { email: consumer.email, password: "wrong-password" }
        expect(response).to have_http_status(:unauthorized)
      end

      post "/api/v1/sessions", params: { email: consumer.email, password: "wrong-password" }

      expect(response).to have_http_status(:too_many_requests)
      expect(json_response["error"]).to be_present
    end

    # A path-suffix like ".json" still routes to the same action (Rails
    # strips the format), so an exact-string path match in the throttle
    # rule would let this dodge it entirely and fall through to the much
    # laxer general API throttle.
    it "still throttles a request with a .json suffix on the path" do
      consumer = create_consumer

      5.times do
        post "/api/v1/sessions.json", params: { email: consumer.email, password: "wrong-password" }
      end

      post "/api/v1/sessions.json", params: { email: consumer.email, password: "wrong-password" }

      expect(response).to have_http_status(:too_many_requests)
    end
  end
end
