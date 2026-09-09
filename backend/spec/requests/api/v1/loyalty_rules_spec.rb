require "rails_helper"

RSpec.describe "Api::V1::LoyaltyRules", type: :request do
  def create_loyalty_rule(attrs = {})
    merchant = attrs.delete(:merchant) || create_merchant
    LoyaltyRule.create!({
      merchant: merchant, visits_required: 5, reward_type: "free_item",
      reward_description: "Free coffee", created_by: SecureRandom.uuid
    }.merge(attrs))
  end

  describe "GET /api/v1/loyalty_rules" do
    it "paginates and filters by merchant_id, without authentication" do
      merchant = create_merchant
      matching = create_loyalty_rule(merchant: merchant)
      create_loyalty_rule

      get "/api/v1/loyalty_rules", params: { merchant_id: merchant.id, per_page: 5 }

      expect(response).to have_http_status(:ok)
      ids = json_response["data"].map { |r| r["id"] }
      expect(ids).to eq([ matching.id ])
    end

    it "keeps the :list payload small — no timestamps" do
      create_loyalty_rule

      get "/api/v1/loyalty_rules"

      expect(response).to have_http_status(:ok)
      row = json_response["data"].first
      expect(row.keys).to include("visits_required", "reward_type")
      expect(row.keys).not_to include("created_at", "updated_at")
    end
  end

  describe "GET /api/v1/loyalty_rules/:id" do
    it "returns the loyalty rule without authentication" do
      loyalty_rule = create_loyalty_rule

      get "/api/v1/loyalty_rules/#{loyalty_rule.id}"

      expect(response).to have_http_status(:ok)
      expect(json_response["id"]).to eq(loyalty_rule.id)
    end

    it "returns 404 for a non-existent loyalty rule" do
      get "/api/v1/loyalty_rules/999999"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/loyalty_rules" do
    it "creates a loyalty rule" do
      merchant = create_merchant
      consumer = create_consumer

      post "/api/v1/loyalty_rules",
        params: { loyalty_rule: { merchant_id: merchant.id, visits_required: 10, reward_type: "cashback", reward_description: "10% back" } },
        headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:created)
      expect(LoyaltyRule.find(json_response["id"]).created_by).to eq(consumer.id)
    end

    it "returns 422 when visits_required is invalid" do
      merchant = create_merchant
      consumer = create_consumer

      post "/api/v1/loyalty_rules",
        params: { loyalty_rule: { merchant_id: merchant.id, visits_required: 0, reward_type: "cashback", reward_description: "10% back" } },
        headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response["errors"]).to have_key("visits_required")
    end

    it "returns 401 without authentication" do
      merchant = create_merchant

      post "/api/v1/loyalty_rules",
        params: { loyalty_rule: { merchant_id: merchant.id, visits_required: 10, reward_type: "cashback", reward_description: "10% back" } }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "PATCH /api/v1/loyalty_rules/:id" do
    it "updates the loyalty rule" do
      loyalty_rule = create_loyalty_rule
      consumer = create_consumer

      patch "/api/v1/loyalty_rules/#{loyalty_rule.id}", params: { loyalty_rule: { visits_required: 20 } }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:ok)
      expect(loyalty_rule.reload.visits_required).to eq(20)
    end

    it "returns 404 for a non-existent loyalty rule" do
      consumer = create_consumer

      patch "/api/v1/loyalty_rules/999999", params: { loyalty_rule: { visits_required: 20 } }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:not_found)
    end

    it "returns 401 without authentication" do
      loyalty_rule = create_loyalty_rule

      patch "/api/v1/loyalty_rules/#{loyalty_rule.id}", params: { loyalty_rule: { visits_required: 20 } }

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 (not 404) for a non-existent id without authentication" do
      patch "/api/v1/loyalty_rules/999999", params: { loyalty_rule: { visits_required: 20 } }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "DELETE /api/v1/loyalty_rules/:id" do
    it "soft-deletes the loyalty rule" do
      loyalty_rule = create_loyalty_rule
      consumer = create_consumer

      delete "/api/v1/loyalty_rules/#{loyalty_rule.id}", headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:no_content)
      expect(LoyaltyRule.unscoped.find(loyalty_rule.id).deleted_at).to be_present
    end

    it "returns 404 for a non-existent loyalty rule" do
      consumer = create_consumer

      delete "/api/v1/loyalty_rules/999999", headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:not_found)
    end

    it "returns 401 without authentication" do
      loyalty_rule = create_loyalty_rule

      delete "/api/v1/loyalty_rules/#{loyalty_rule.id}"

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 (not 404) for a non-existent id without authentication" do
      delete "/api/v1/loyalty_rules/999999"

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
