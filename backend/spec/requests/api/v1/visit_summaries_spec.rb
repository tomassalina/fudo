require "rails_helper"

# VisitSummary has no audit columns (see db/structure.sql) so no X-Actor-Id
# is required here, and destroy is a real DELETE.
RSpec.describe "Api::V1::VisitSummaries", type: :request do
  def create_visit_summary(attrs = {})
    consumer = attrs.delete(:consumer) || create_consumer
    merchant = attrs.delete(:merchant) || create_merchant
    VisitSummary.create!({ consumer: consumer, merchant: merchant, count: 3, current_tier: "bronze" }.merge(attrs))
  end

  describe "GET /api/v1/visit_summaries" do
    it "paginates and filters by consumer_id" do
      consumer = create_consumer
      matching = create_visit_summary(consumer: consumer)
      create_visit_summary

      get "/api/v1/visit_summaries", params: { consumer_id: consumer.id, per_page: 5 }

      expect(response).to have_http_status(:ok)
      ids = json_response["data"].map { |v| v["id"] }
      expect(ids).to eq([ matching.id ])
    end
  end

  describe "GET /api/v1/visit_summaries/:id" do
    it "returns the visit summary" do
      visit_summary = create_visit_summary

      get "/api/v1/visit_summaries/#{visit_summary.id}"

      expect(response).to have_http_status(:ok)
      expect(json_response["id"]).to eq(visit_summary.id)
    end

    it "returns 404 for a non-existent visit summary" do
      get "/api/v1/visit_summaries/999999"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/visit_summaries" do
    it "creates a visit summary without needing an X-Actor-Id header" do
      consumer = create_consumer
      merchant = create_merchant

      post "/api/v1/visit_summaries", params: { visit_summary: { consumer_id: consumer.id, merchant_id: merchant.id, count: 1 } }

      expect(response).to have_http_status(:created)
    end

    it "returns 422 when count is invalid" do
      consumer = create_consumer
      merchant = create_merchant

      post "/api/v1/visit_summaries", params: { visit_summary: { consumer_id: consumer.id, merchant_id: merchant.id, count: -1 } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response["errors"]).to have_key("count")
    end
  end

  describe "PATCH /api/v1/visit_summaries/:id" do
    it "updates the visit summary" do
      visit_summary = create_visit_summary

      patch "/api/v1/visit_summaries/#{visit_summary.id}", params: { visit_summary: { count: 9 } }

      expect(response).to have_http_status(:ok)
      expect(visit_summary.reload.count).to eq(9)
    end

    it "returns 404 for a non-existent visit summary" do
      patch "/api/v1/visit_summaries/999999", params: { visit_summary: { count: 9 } }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/v1/visit_summaries/:id" do
    it "hard-deletes the visit summary" do
      visit_summary = create_visit_summary

      delete "/api/v1/visit_summaries/#{visit_summary.id}"

      expect(response).to have_http_status(:no_content)
      expect(VisitSummary.where(id: visit_summary.id)).not_to exist
    end

    it "returns 404 for a non-existent visit summary" do
      delete "/api/v1/visit_summaries/999999"

      expect(response).to have_http_status(:not_found)
    end
  end
end
