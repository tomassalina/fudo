require "rails_helper"

RSpec.describe "Api::V1::Visits", type: :request do
  def create_visit(attrs = {})
    consumer = attrs.delete(:consumer) || create_consumer
    merchant = attrs.delete(:merchant) || create_merchant
    Visit.create!({
      consumer: consumer, merchant: merchant, amount: 1000, visited_at: Time.current,
      created_by: SecureRandom.uuid
    }.merge(attrs))
  end

  describe "GET /api/v1/visits" do
    it "paginates and filters by consumer_id" do
      consumer = create_consumer
      matching = create_visit(consumer: consumer)
      create_visit

      get "/api/v1/visits", params: { consumer_id: consumer.id, per_page: 5 }

      expect(response).to have_http_status(:ok)
      ids = json_response["data"].map { |v| v["id"] }
      expect(ids).to eq([ matching.id ])
    end

    # Postgres's uuid column type-casts client-side (see
    # ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Uuid#cast_value):
    # anything that doesn't already look like a UUID is cast to nil before
    # it ever reaches SQL, so this never raises — it's just an empty result.
    it "returns an empty (not an error) result when the consumer_id filter is not a valid UUID" do
      create_visit

      get "/api/v1/visits", params: { consumer_id: "not-a-uuid" }

      expect(response).to have_http_status(:ok)
      expect(json_response["data"]).to eq([])
    end

    it "keeps the :list payload small — no reward_description_snapshot/timestamps" do
      create_visit

      get "/api/v1/visits"

      expect(response).to have_http_status(:ok)
      row = json_response["data"].first
      expect(row.keys).to include("amount", "visited_at")
      expect(row.keys).not_to include("reward_description_snapshot", "created_at", "updated_at")
    end
  end

  describe "GET /api/v1/visits/:id" do
    it "returns the visit" do
      visit = create_visit

      get "/api/v1/visits/#{visit.id}"

      expect(response).to have_http_status(:ok)
      expect(json_response["id"]).to eq(visit.id)
    end

    it "returns 404 for a non-existent visit" do
      get "/api/v1/visits/999999"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/visits" do
    it "creates a visit" do
      consumer = create_consumer
      merchant = create_merchant

      post "/api/v1/visits",
        params: { visit: { consumer_id: consumer.id, merchant_id: merchant.id, amount: 2500, visited_at: Time.current } },
        headers: actor_headers

      expect(response).to have_http_status(:created)
      expect(Visit.find(json_response["id"]).created_by).to eq(actor_id)
    end

    it "returns 422 when visited_at is missing" do
      consumer = create_consumer
      merchant = create_merchant

      post "/api/v1/visits",
        params: { visit: { consumer_id: consumer.id, merchant_id: merchant.id, amount: 2500, visited_at: nil } },
        headers: actor_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response["errors"]).to have_key("visited_at")
    end

    it "returns 400 without an X-Actor-Id header" do
      consumer = create_consumer
      merchant = create_merchant

      post "/api/v1/visits",
        params: { visit: { consumer_id: consumer.id, merchant_id: merchant.id, amount: 2500, visited_at: Time.current } }

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "PATCH /api/v1/visits/:id" do
    it "updates the visit" do
      visit = create_visit

      patch "/api/v1/visits/#{visit.id}", params: { visit: { amount: 3000 } }, headers: actor_headers

      expect(response).to have_http_status(:ok)
      expect(visit.reload.amount.to_f).to eq(3000.0)
    end

    it "returns 404 for a non-existent visit" do
      patch "/api/v1/visits/999999", params: { visit: { amount: 3000 } }, headers: actor_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/v1/visits/:id" do
    it "soft-deletes the visit" do
      visit = create_visit

      delete "/api/v1/visits/#{visit.id}", headers: actor_headers

      expect(response).to have_http_status(:no_content)
      expect(Visit.unscoped.find(visit.id).deleted_at).to be_present
    end

    it "returns 404 for a non-existent visit" do
      delete "/api/v1/visits/999999", headers: actor_headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
