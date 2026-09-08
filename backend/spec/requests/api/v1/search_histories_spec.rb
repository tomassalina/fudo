require "rails_helper"

RSpec.describe "Api::V1::SearchHistories", type: :request do
  def create_search_history(attrs = {})
    consumer = attrs.delete(:consumer) || create_consumer
    SearchHistory.create!({ consumer: consumer, query_text: "pizza cerca", created_by: SecureRandom.uuid }.merge(attrs))
  end

  describe "GET /api/v1/search_histories" do
    it "paginates and filters by consumer_id" do
      consumer = create_consumer
      matching = create_search_history(consumer: consumer)
      create_search_history

      get "/api/v1/search_histories", params: { consumer_id: consumer.id, per_page: 5 }

      expect(response).to have_http_status(:ok)
      ids = json_response["data"].map { |s| s["id"] }
      expect(ids).to eq([ matching.id ])
    end

    it "keeps the :list payload small — no structured_output/updated_at" do
      create_search_history

      get "/api/v1/search_histories"

      expect(response).to have_http_status(:ok)
      row = json_response["data"].first
      expect(row.keys).to include("query_text", "created_at")
      expect(row.keys).not_to include("structured_output", "updated_at")
    end
  end

  describe "GET /api/v1/search_histories/:id" do
    it "returns the search history entry" do
      search_history = create_search_history

      get "/api/v1/search_histories/#{search_history.id}"

      expect(response).to have_http_status(:ok)
      expect(json_response["id"]).to eq(search_history.id)
    end

    it "returns 404 for a non-existent search history entry" do
      get "/api/v1/search_histories/999999"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/search_histories" do
    it "creates a search history entry" do
      consumer = create_consumer

      post "/api/v1/search_histories",
        params: { search_history: { consumer_id: consumer.id, query_text: "sushi", structured_output: { cuisine: "japanese" } } },
        headers: actor_headers

      expect(response).to have_http_status(:created)
      expect(SearchHistory.find(json_response["id"]).created_by).to eq(actor_id)
    end

    it "returns 422 when query_text is missing" do
      consumer = create_consumer

      post "/api/v1/search_histories", params: { search_history: { consumer_id: consumer.id, query_text: nil } }, headers: actor_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response["errors"]).to have_key("query_text")
    end

    it "returns 400 without an X-Actor-Id header" do
      consumer = create_consumer

      post "/api/v1/search_histories", params: { search_history: { consumer_id: consumer.id, query_text: "sushi" } }

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "PATCH /api/v1/search_histories/:id" do
    it "updates the search history entry" do
      search_history = create_search_history

      patch "/api/v1/search_histories/#{search_history.id}", params: { search_history: { query_text: "ramen" } }, headers: actor_headers

      expect(response).to have_http_status(:ok)
      expect(search_history.reload.query_text).to eq("ramen")
    end

    it "returns 404 for a non-existent search history entry" do
      patch "/api/v1/search_histories/999999", params: { search_history: { query_text: "ramen" } }, headers: actor_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/v1/search_histories/:id" do
    it "soft-deletes the search history entry" do
      search_history = create_search_history

      delete "/api/v1/search_histories/#{search_history.id}", headers: actor_headers

      expect(response).to have_http_status(:no_content)
      expect(SearchHistory.unscoped.find(search_history.id).deleted_at).to be_present
    end

    it "returns 404 for a non-existent search history entry" do
      delete "/api/v1/search_histories/999999", headers: actor_headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
