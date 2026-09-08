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
    it "paginates and scopes to gifts where the authenticated consumer is sender or recipient" do
      consumer = create_consumer
      sent = create_gift(sender: consumer)
      received = create_gift(recipient_consumer_id: consumer.id)
      create_gift

      get "/api/v1/gifts", params: { per_page: 5 }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:ok)
      ids = json_response["data"].map { |g| g["id"] }
      expect(ids).to contain_exactly(sent.id, received.id)
    end

    it "does not leak another consumer's gifts via a consumer_id param" do
      consumer = create_consumer
      other = create_consumer
      create_gift(sender: other)

      get "/api/v1/gifts", params: { consumer_id: other.id }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:ok)
      expect(json_response["data"]).to eq([])
    end

    it "keeps the :list payload small — no recipient_phone/message/timestamps" do
      consumer = create_consumer
      create_gift(sender: consumer)

      get "/api/v1/gifts", headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:ok)
      row = json_response["data"].first
      expect(row.keys).to include("type", "amount", "status")
      expect(row.keys).not_to include("recipient_phone", "message", "status_updated_at", "created_at", "updated_at")
    end

    it "returns 401 without authentication" do
      get "/api/v1/gifts"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/gifts/:id" do
    it "returns the gift" do
      consumer = create_consumer
      gift = create_gift(sender: consumer)

      get "/api/v1/gifts/#{gift.id}", headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:ok)
      expect(json_response["id"]).to eq(gift.id)
    end

    it "returns 404 for a non-existent gift" do
      consumer = create_consumer

      get "/api/v1/gifts/999999", headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 (not the gift) for a consumer who is neither sender nor recipient" do
      sender = create_consumer
      intruder = create_consumer
      gift = create_gift(sender: sender)

      get "/api/v1/gifts/#{gift.id}", headers: auth_headers_for(intruder)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/gifts" do
    it "creates a gift with the authenticated consumer as sender" do
      consumer = create_consumer

      post "/api/v1/gifts",
        params: { gift: { type: "gold", amount: 10_000, recipient_phone: "+5491100000000", expires_at: 10.days.from_now } },
        headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:created)
      created = Gift.find(json_response["id"])
      expect(created.created_by).to eq(consumer.id)
      expect(created.sender_consumer_id).to eq(consumer.id)
    end

    it "ignores a client-supplied sender_consumer_id and always uses current_consumer" do
      consumer = create_consumer
      other = create_consumer

      post "/api/v1/gifts",
        params: { gift: { sender_consumer_id: other.id, type: "gold", amount: 10_000, recipient_phone: "+5491100000000", expires_at: 10.days.from_now } },
        headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:created)
      expect(Gift.find(json_response["id"]).sender_consumer_id).to eq(consumer.id)
    end

    it "ignores a client-supplied status — every new gift starts pending" do
      consumer = create_consumer

      post "/api/v1/gifts",
        params: { gift: { type: "gold", amount: 10_000, recipient_phone: "+5491100000000", expires_at: 10.days.from_now, status: "redeemed" } },
        headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:created)
      expect(Gift.find(json_response["id"]).status).to eq("pending")
    end

    it "returns 422 when recipient_phone is missing" do
      consumer = create_consumer

      post "/api/v1/gifts",
        params: { gift: { type: "gold", amount: 10_000, recipient_phone: nil, expires_at: 10.days.from_now } },
        headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response["errors"]).to have_key("recipient_phone")
    end

    it "returns 401 without authentication" do
      post "/api/v1/gifts",
        params: { gift: { type: "gold", amount: 10_000, recipient_phone: "+5491100000000", expires_at: 10.days.from_now } }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "PATCH /api/v1/gifts/:id" do
    # Gifts are immutable except for the sender cancelling a still-pending
    # gift — see GiftsController#update. Marking a gift `redeemed` is not a
    # consumer-facing action at all (no staff/merchant flow exists yet).
    it "lets the sender cancel their own pending gift" do
      consumer = create_consumer
      gift = create_gift(sender: consumer)

      patch "/api/v1/gifts/#{gift.id}", params: { gift: { status: "cancelled" } }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:ok)
      expect(gift.reload.status).to eq("cancelled")
    end

    it "returns 403 when the recipient (not the sender) tries to update the gift" do
      sender = create_consumer
      recipient = create_consumer
      gift = create_gift(sender: sender, recipient_consumer_id: recipient.id)

      patch "/api/v1/gifts/#{gift.id}", params: { gift: { status: "cancelled" } }, headers: auth_headers_for(recipient)

      expect(response).to have_http_status(:forbidden)
      expect(gift.reload.status).to eq("pending")
    end

    it "rejects marking a gift redeemed via the API — not a consumer-facing action" do
      consumer = create_consumer
      gift = create_gift(sender: consumer)

      patch "/api/v1/gifts/#{gift.id}", params: { gift: { status: "redeemed" } }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(gift.reload.status).to eq("pending")
    end

    it "returns 422 when trying to cancel a gift that is no longer pending" do
      consumer = create_consumer
      gift = create_gift(sender: consumer, status: "redeemed", status_updated_at: Time.current)

      patch "/api/v1/gifts/#{gift.id}", params: { gift: { status: "cancelled" } }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(gift.reload.status).to eq("redeemed")
    end

    it "ignores amount/type/sender/recipient — gifts are immutable on those fields" do
      consumer = create_consumer
      other = create_consumer
      gift = create_gift(sender: consumer, amount: 1000)

      patch "/api/v1/gifts/#{gift.id}",
        params: { gift: { status: "cancelled", amount: 999_999, type: "platinum", sender_consumer_id: other.id, recipient_consumer_id: other.id } },
        headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:ok)
      gift.reload
      expect(gift.status).to eq("cancelled")
      expect(gift.amount.to_f).to eq(1000.0)
      expect(gift.type).to eq("classic")
      expect(gift.sender_consumer_id).to eq(consumer.id)
      expect(gift.recipient_consumer_id).to be_nil
    end

    it "returns 404 for a non-existent gift" do
      consumer = create_consumer

      patch "/api/v1/gifts/999999", params: { gift: { status: "cancelled" } }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 (not the gift) for a consumer who is neither sender nor recipient" do
      sender = create_consumer
      intruder = create_consumer
      gift = create_gift(sender: sender)

      patch "/api/v1/gifts/#{gift.id}", params: { gift: { status: "cancelled" } }, headers: auth_headers_for(intruder)

      expect(response).to have_http_status(:not_found)
      expect(gift.reload.status).not_to eq("cancelled")
    end
  end

  describe "DELETE /api/v1/gifts/:id" do
    it "soft-deletes the gift" do
      consumer = create_consumer
      gift = create_gift(sender: consumer)

      delete "/api/v1/gifts/#{gift.id}", headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:no_content)
      expect(Gift.unscoped.find(gift.id).deleted_at).to be_present
    end

    it "returns 404 for a non-existent gift" do
      consumer = create_consumer

      delete "/api/v1/gifts/999999", headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 (not the gift) for a consumer who is neither sender nor recipient" do
      sender = create_consumer
      intruder = create_consumer
      gift = create_gift(sender: sender)

      delete "/api/v1/gifts/#{gift.id}", headers: auth_headers_for(intruder)

      expect(response).to have_http_status(:not_found)
      expect(Gift.unscoped.find(gift.id).deleted_at).to be_nil
    end

    # Gift's soft-delete scope is GLOBAL (see SoftDeletable's default_scope)
    # — soft-deleting a gift hides it from BOTH the sender and the
    # recipient, not just from whoever calls destroy. Without a sender-only
    # guard here, the recipient could make a gift vanish from the sender's
    # own history too.
    it "returns 403 when the recipient (not the sender) tries to delete the gift" do
      sender = create_consumer
      recipient = create_consumer
      gift = create_gift(sender: sender, recipient_consumer_id: recipient.id)

      delete "/api/v1/gifts/#{gift.id}", headers: auth_headers_for(recipient)

      expect(response).to have_http_status(:forbidden)
      expect(Gift.unscoped.find(gift.id).deleted_at).to be_nil
    end

    # Deliberately restricted to `pending`, same as the #update cancel path
    # — this stops the sender from unilaterally erasing the recipient's
    # redemption history for a gift that already happened (redeemed) or ran
    # its course (expired/cancelled).
    it "returns 422 when the sender tries to delete a gift that is no longer pending" do
      consumer = create_consumer
      gift = create_gift(sender: consumer, status: "redeemed", status_updated_at: Time.current)

      delete "/api/v1/gifts/#{gift.id}", headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Gift.unscoped.find(gift.id).deleted_at).to be_nil
    end
  end
end
