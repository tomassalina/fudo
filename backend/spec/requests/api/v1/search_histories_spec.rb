require "rails_helper"

RSpec.describe "Api::V1::SearchHistories", type: :request do
  def create_search_history(attrs = {})
    consumer = attrs.delete(:consumer) || create_consumer
    SearchHistory.create!({ consumer: consumer, query_text: "pizza cerca", created_by: SecureRandom.uuid }.merge(attrs))
  end

  describe "GET /api/v1/search_histories" do
    it "paginates and scopes to the authenticated consumer's own search history" do
      consumer = create_consumer
      matching = create_search_history(consumer: consumer)
      create_search_history

      get "/api/v1/search_histories", params: { per_page: 5 }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:ok)
      ids = json_response["data"].map { |s| s["id"] }
      expect(ids).to eq([ matching.id ])
    end

    it "does not leak another consumer's search history via a consumer_id param" do
      consumer = create_consumer
      other = create_consumer
      create_search_history(consumer: other)

      get "/api/v1/search_histories", params: { consumer_id: other.id }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:ok)
      expect(json_response["data"]).to eq([])
    end

    it "keeps the :list payload small — no structured_output/updated_at" do
      consumer = create_consumer
      create_search_history(consumer: consumer)

      get "/api/v1/search_histories", headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:ok)
      row = json_response["data"].first
      expect(row.keys).to include("query_text", "created_at")
      expect(row.keys).not_to include("structured_output", "updated_at")
    end

    it "returns 401 without authentication" do
      get "/api/v1/search_histories"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/search_histories/:id" do
    it "returns the search history entry" do
      consumer = create_consumer
      search_history = create_search_history(consumer: consumer)

      get "/api/v1/search_histories/#{search_history.id}", headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:ok)
      expect(json_response["id"]).to eq(search_history.id)
    end

    it "returns 404 for a non-existent search history entry" do
      consumer = create_consumer

      get "/api/v1/search_histories/999999", headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 (not the entry) for another consumer's search history" do
      owner = create_consumer
      intruder = create_consumer
      search_history = create_search_history(consumer: owner)

      get "/api/v1/search_histories/#{search_history.id}", headers: auth_headers_for(intruder)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/search_histories" do
    it "creates a search history entry owned by the authenticated consumer" do
      consumer = create_consumer

      post "/api/v1/search_histories",
        params: { search_history: { query_text: "sushi", structured_output: { cuisine: "japanese" } } },
        headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:created)
      created = SearchHistory.find(json_response["id"])
      expect(created.created_by).to eq(consumer.id)
      expect(created.consumer_id).to eq(consumer.id)
    end

    it "ignores a client-supplied consumer_id and always uses current_consumer" do
      consumer = create_consumer
      other = create_consumer

      post "/api/v1/search_histories",
        params: { search_history: { consumer_id: other.id, query_text: "sushi" } },
        headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:created)
      expect(SearchHistory.find(json_response["id"]).consumer_id).to eq(consumer.id)
    end

    it "returns 422 when query_text is missing" do
      consumer = create_consumer

      post "/api/v1/search_histories", params: { search_history: { query_text: nil } }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response["errors"]).to have_key("query_text")
    end

    it "returns 401 without authentication" do
      post "/api/v1/search_histories", params: { search_history: { query_text: "sushi" } }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "PATCH /api/v1/search_histories/:id" do
    it "updates the search history entry" do
      consumer = create_consumer
      search_history = create_search_history(consumer: consumer)

      patch "/api/v1/search_histories/#{search_history.id}", params: { search_history: { query_text: "ramen" } }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:ok)
      expect(search_history.reload.query_text).to eq("ramen")
    end

    it "returns 404 for a non-existent search history entry" do
      consumer = create_consumer

      patch "/api/v1/search_histories/999999", params: { search_history: { query_text: "ramen" } }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 (not the entry) when updating another consumer's search history" do
      owner = create_consumer
      intruder = create_consumer
      search_history = create_search_history(consumer: owner)

      patch "/api/v1/search_histories/#{search_history.id}", params: { search_history: { query_text: "ramen" } }, headers: auth_headers_for(intruder)

      expect(response).to have_http_status(:not_found)
      expect(search_history.reload.query_text).not_to eq("ramen")
    end
  end

  describe "DELETE /api/v1/search_histories/:id" do
    it "soft-deletes the search history entry" do
      consumer = create_consumer
      search_history = create_search_history(consumer: consumer)

      delete "/api/v1/search_histories/#{search_history.id}", headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:no_content)
      expect(SearchHistory.unscoped.find(search_history.id).deleted_at).to be_present
    end

    it "returns 404 for a non-existent search history entry" do
      consumer = create_consumer

      delete "/api/v1/search_histories/999999", headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 (not the entry) when deleting another consumer's search history" do
      owner = create_consumer
      intruder = create_consumer
      search_history = create_search_history(consumer: owner)

      delete "/api/v1/search_histories/#{search_history.id}", headers: auth_headers_for(intruder)

      expect(response).to have_http_status(:not_found)
      expect(SearchHistory.unscoped.find(search_history.id).deleted_at).to be_nil
    end
  end
end
