require "rails_helper"

RSpec.describe "Api::V1::Gifts", type: :request do
  def create_gift(attrs = {})
    sender = attrs.delete(:sender) || create_consumer
    Gift.create!({
      sender: sender, type: "classic", amount: 5000, recipient_phone: "+5491122334455",
      expires_at: 30.days.from_now, created_by: SecureRandom.uuid
    }.merge(attrs))
  end

  describe "GET /api/v1/gifts" do
    it "paginates and filters by consumer_id, matching sender or recipient" do
      consumer = create_consumer
      sent = create_gift(sender: consumer)
      received = create_gift(recipient_consumer_id: consumer.id)
      create_gift

      get "/api/v1/gifts", params: { consumer_id: consumer.id, per_page: 5 }

      expect(response).to have_http_status(:ok)
      ids = json_response["data"].map { |g| g["id"] }
      expect(ids).to contain_exactly(sent.id, received.id)
    end

    it "keeps the :list payload small — no recipient_phone/message/timestamps" do
      create_gift

      get "/api/v1/gifts"

      expect(response).to have_http_status(:ok)
      row = json_response["data"].first
      expect(row.keys).to include("type", "amount", "status")
      expect(row.keys).not_to include("recipient_phone", "message", "status_updated_at", "created_at", "updated_at")
    end
  end

  describe "GET /api/v1/gifts/:id" do
    it "returns the gift" do
      gift = create_gift

      get "/api/v1/gifts/#{gift.id}"

      expect(response).to have_http_status(:ok)
      expect(json_response["id"]).to eq(gift.id)
    end

    it "returns 404 for a non-existent gift" do
      get "/api/v1/gifts/999999"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/gifts" do
    it "creates a gift" do
      sender = create_consumer

      post "/api/v1/gifts",
        params: { gift: { sender_consumer_id: sender.id, type: "gold", amount: 10_000, recipient_phone: "+5491100000000", expires_at: 10.days.from_now } },
        headers: actor_headers

      expect(response).to have_http_status(:created)
      expect(Gift.find(json_response["id"]).created_by).to eq(actor_id)
    end

    it "returns 422 when recipient_phone is missing" do
      sender = create_consumer

      post "/api/v1/gifts",
        params: { gift: { sender_consumer_id: sender.id, type: "gold", amount: 10_000, recipient_phone: nil, expires_at: 10.days.from_now } },
        headers: actor_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response["errors"]).to have_key("recipient_phone")
    end

    it "returns 400 without an X-Actor-Id header" do
      sender = create_consumer

      post "/api/v1/gifts",
        params: { gift: { sender_consumer_id: sender.id, type: "gold", amount: 10_000, recipient_phone: "+5491100000000", expires_at: 10.days.from_now } }

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "PATCH /api/v1/gifts/:id" do
    it "updates the gift" do
      gift = create_gift

      patch "/api/v1/gifts/#{gift.id}", params: { gift: { status: "redeemed" } }, headers: actor_headers

      expect(response).to have_http_status(:ok)
      expect(gift.reload.status).to eq("redeemed")
    end

    it "returns 404 for a non-existent gift" do
      patch "/api/v1/gifts/999999", params: { gift: { status: "redeemed" } }, headers: actor_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/v1/gifts/:id" do
    it "soft-deletes the gift" do
      gift = create_gift

      delete "/api/v1/gifts/#{gift.id}", headers: actor_headers

      expect(response).to have_http_status(:no_content)
      expect(Gift.unscoped.find(gift.id).deleted_at).to be_present
    end

    it "returns 404 for a non-existent gift" do
      delete "/api/v1/gifts/999999", headers: actor_headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
