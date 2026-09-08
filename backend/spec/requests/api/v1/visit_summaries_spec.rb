require "rails_helper"

# VisitSummary has no audit columns (see db/structure.sql) and destroy is a
# real DELETE. All actions require authentication and are scoped to the
# authenticated consumer's own visit summaries.
RSpec.describe "Api::V1::VisitSummaries", type: :request do
  def create_visit_summary(attrs = {})
    consumer = attrs.delete(:consumer) || create_consumer
    merchant = attrs.delete(:merchant) || create_merchant
    VisitSummary.create!({ consumer: consumer, merchant: merchant, count: 3, current_tier: "bronze" }.merge(attrs))
  end

  describe "GET /api/v1/visit_summaries" do
    it "paginates and scopes to the authenticated consumer's own visit summaries" do
      consumer = create_consumer
      matching = create_visit_summary(consumer: consumer)
      create_visit_summary

      get "/api/v1/visit_summaries", params: { per_page: 5 }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:ok)
      ids = json_response["data"].map { |v| v["id"] }
      expect(ids).to eq([ matching.id ])
    end

    it "does not leak another consumer's visit summaries via a consumer_id param" do
      consumer = create_consumer
      other = create_consumer
      create_visit_summary(consumer: other)

      get "/api/v1/visit_summaries", params: { consumer_id: other.id }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:ok)
      expect(json_response["data"]).to eq([])
    end

    it "returns 401 without authentication" do
      get "/api/v1/visit_summaries"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/visit_summaries/:id" do
    it "returns the visit summary" do
      consumer = create_consumer
      visit_summary = create_visit_summary(consumer: consumer)

      get "/api/v1/visit_summaries/#{visit_summary.id}", headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:ok)
      expect(json_response["id"]).to eq(visit_summary.id)
    end

    it "returns 404 for a non-existent visit summary" do
      consumer = create_consumer

      get "/api/v1/visit_summaries/999999", headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 (not the summary) for another consumer's visit summary" do
      owner = create_consumer
      intruder = create_consumer
      visit_summary = create_visit_summary(consumer: owner)

      get "/api/v1/visit_summaries/#{visit_summary.id}", headers: auth_headers_for(intruder)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/visit_summaries" do
    it "creates a visit summary owned by the authenticated consumer" do
      consumer = create_consumer
      merchant = create_merchant

      post "/api/v1/visit_summaries", params: { visit_summary: { merchant_id: merchant.id, count: 1 } }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:created)
      expect(VisitSummary.find(json_response["id"]).consumer_id).to eq(consumer.id)
    end

    it "ignores a client-supplied consumer_id and always uses current_consumer" do
      consumer = create_consumer
      other = create_consumer
      merchant = create_merchant

      post "/api/v1/visit_summaries",
        params: { visit_summary: { consumer_id: other.id, merchant_id: merchant.id, count: 1 } },
        headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:created)
      expect(VisitSummary.find(json_response["id"]).consumer_id).to eq(consumer.id)
    end

    it "returns 422 when count is invalid" do
      consumer = create_consumer
      merchant = create_merchant

      post "/api/v1/visit_summaries", params: { visit_summary: { merchant_id: merchant.id, count: -1 } }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response["errors"]).to have_key("count")
    end

    it "returns 401 without authentication" do
      merchant = create_merchant

      post "/api/v1/visit_summaries", params: { visit_summary: { merchant_id: merchant.id, count: 1 } }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "PATCH /api/v1/visit_summaries/:id" do
    it "updates the visit summary" do
      consumer = create_consumer
      visit_summary = create_visit_summary(consumer: consumer)

      patch "/api/v1/visit_summaries/#{visit_summary.id}", params: { visit_summary: { count: 9 } }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:ok)
      expect(visit_summary.reload.count).to eq(9)
    end

    it "returns 404 for a non-existent visit summary" do
      consumer = create_consumer

      patch "/api/v1/visit_summaries/999999", params: { visit_summary: { count: 9 } }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 (not the summary) when updating another consumer's visit summary" do
      owner = create_consumer
      intruder = create_consumer
      visit_summary = create_visit_summary(consumer: owner)

      patch "/api/v1/visit_summaries/#{visit_summary.id}", params: { visit_summary: { count: 9 } }, headers: auth_headers_for(intruder)

      expect(response).to have_http_status(:not_found)
      expect(visit_summary.reload.count).not_to eq(9)
    end
  end

  describe "DELETE /api/v1/visit_summaries/:id" do
    it "hard-deletes the visit summary" do
      consumer = create_consumer
      visit_summary = create_visit_summary(consumer: consumer)

      delete "/api/v1/visit_summaries/#{visit_summary.id}", headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:no_content)
      expect(VisitSummary.where(id: visit_summary.id)).not_to exist
    end

    it "returns 404 for a non-existent visit summary" do
      consumer = create_consumer

      delete "/api/v1/visit_summaries/999999", headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 (not the summary) when deleting another consumer's visit summary" do
      owner = create_consumer
      intruder = create_consumer
      visit_summary = create_visit_summary(consumer: owner)

      delete "/api/v1/visit_summaries/#{visit_summary.id}", headers: auth_headers_for(intruder)

      expect(response).to have_http_status(:not_found)
      expect(VisitSummary.where(id: visit_summary.id)).to exist
    end
  end
end
