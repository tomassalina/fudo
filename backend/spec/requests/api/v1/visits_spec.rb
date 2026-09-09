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
    it "paginates and scopes to the authenticated consumer's own visits" do
      consumer = create_consumer
      matching = create_visit(consumer: consumer)
      create_visit

      get "/api/v1/visits", params: { per_page: 5 }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:ok)
      ids = json_response["data"].map { |v| v["id"] }
      expect(ids).to eq([ matching.id ])
    end

    it "does not leak another consumer's visits via a consumer_id param" do
      consumer = create_consumer
      other = create_consumer
      create_visit(consumer: other)

      get "/api/v1/visits", params: { consumer_id: other.id }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:ok)
      expect(json_response["data"]).to eq([])
    end

    it "keeps the :list payload small — no reward_description_snapshot/timestamps" do
      consumer = create_consumer
      create_visit(consumer: consumer)

      get "/api/v1/visits", headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:ok)
      row = json_response["data"].first
      expect(row.keys).to include("amount", "visited_at")
      expect(row.keys).not_to include("reward_description_snapshot", "created_at", "updated_at")
    end

    it "returns 401 without authentication" do
      get "/api/v1/visits"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/visits/:id" do
    it "returns the visit" do
      consumer = create_consumer
      visit = create_visit(consumer: consumer)

      get "/api/v1/visits/#{visit.id}", headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:ok)
      expect(json_response["id"]).to eq(visit.id)
    end

    it "returns 404 for a non-existent visit" do
      consumer = create_consumer

      get "/api/v1/visits/999999", headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 (not the visit) for another consumer's visit" do
      owner = create_consumer
      intruder = create_consumer
      visit = create_visit(consumer: owner)

      get "/api/v1/visits/#{visit.id}", headers: auth_headers_for(intruder)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/visits" do
    it "creates a visit owned by the authenticated consumer" do
      consumer = create_consumer
      merchant = create_merchant

      post "/api/v1/visits",
        params: { visit: { merchant_id: merchant.id, amount: 2500, visited_at: Time.current } },
        headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:created)
      created = Visit.find(json_response["id"])
      expect(created.created_by).to eq(consumer.id)
      expect(created.consumer_id).to eq(consumer.id)
    end

    it "ignores a client-supplied consumer_id and always uses current_consumer" do
      consumer = create_consumer
      other = create_consumer
      merchant = create_merchant

      post "/api/v1/visits",
        params: { visit: { consumer_id: other.id, merchant_id: merchant.id, amount: 2500, visited_at: Time.current } },
        headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:created)
      expect(Visit.find(json_response["id"]).consumer_id).to eq(consumer.id)
    end

    it "ignores client-supplied reward_applied/reward_description_snapshot — a consumer can't self-grant a reward" do
      consumer = create_consumer
      merchant = create_merchant

      post "/api/v1/visits",
        params: {
          visit: {
            merchant_id: merchant.id, amount: 2500, visited_at: Time.current,
            reward_applied: true, reward_description_snapshot: "Free dessert"
          }
        },
        headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:created)
      created = Visit.find(json_response["id"])
      expect(created.reward_applied).to be(false)
      expect(created.reward_description_snapshot).to be_nil
    end

    it "returns 422 when visited_at is missing" do
      consumer = create_consumer
      merchant = create_merchant

      post "/api/v1/visits",
        params: { visit: { merchant_id: merchant.id, amount: 2500, visited_at: nil } },
        headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response["errors"]).to have_key("visited_at")
    end

    it "returns 401 without authentication" do
      merchant = create_merchant

      post "/api/v1/visits", params: { visit: { merchant_id: merchant.id, amount: 2500, visited_at: Time.current } }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "PATCH /api/v1/visits/:id" do
    it "updates the visit's visited_at" do
      consumer = create_consumer
      visit = create_visit(consumer: consumer)
      new_visited_at = 1.day.ago.change(usec: 0)

      patch "/api/v1/visits/#{visit.id}", params: { visit: { visited_at: new_visited_at } }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:ok)
      expect(visit.reload.visited_at).to eq(new_visited_at)
    end

    it "ignores a client-supplied merchant_id/amount on update — a visit's merchant and charged amount are immutable once recorded" do
      consumer = create_consumer
      merchant = create_merchant
      other_merchant = create_merchant
      visit = create_visit(consumer: consumer, merchant: merchant, amount: 1000)

      patch "/api/v1/visits/#{visit.id}",
        params: { visit: { merchant_id: other_merchant.id, amount: 99999 } },
        headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:ok)
      visit.reload
      expect(visit.merchant_id).to eq(merchant.id)
      expect(visit.amount.to_f).to eq(1000.0)
    end

    it "ignores client-supplied reward_applied/reward_description_snapshot on update too" do
      consumer = create_consumer
      visit = create_visit(consumer: consumer)

      patch "/api/v1/visits/#{visit.id}",
        params: { visit: { reward_applied: true, reward_description_snapshot: "Free dessert" } },
        headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:ok)
      visit.reload
      expect(visit.reward_applied).to be(false)
      expect(visit.reward_description_snapshot).to be_nil
    end

    it "returns 404 for a non-existent visit" do
      consumer = create_consumer

      patch "/api/v1/visits/999999", params: { visit: { amount: 3000 } }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 (not the visit) when updating another consumer's visit" do
      owner = create_consumer
      intruder = create_consumer
      visit = create_visit(consumer: owner)

      patch "/api/v1/visits/#{visit.id}", params: { visit: { amount: 3000 } }, headers: auth_headers_for(intruder)

      expect(response).to have_http_status(:not_found)
      expect(visit.reload.amount.to_f).to eq(1000.0)
    end
  end

  describe "DELETE /api/v1/visits/:id" do
    it "soft-deletes the visit" do
      consumer = create_consumer
      visit = create_visit(consumer: consumer)

      delete "/api/v1/visits/#{visit.id}", headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:no_content)
      expect(Visit.unscoped.find(visit.id).deleted_at).to be_present
    end

    it "returns 404 for a non-existent visit" do
      consumer = create_consumer

      delete "/api/v1/visits/999999", headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 (not the visit) when deleting another consumer's visit" do
      owner = create_consumer
      intruder = create_consumer
      visit = create_visit(consumer: owner)

      delete "/api/v1/visits/#{visit.id}", headers: auth_headers_for(intruder)

      expect(response).to have_http_status(:not_found)
      expect(Visit.unscoped.find(visit.id).deleted_at).to be_nil
    end
  end
end
