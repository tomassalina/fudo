require "rails_helper"

RSpec.describe "Api::V1::Tags", type: :request do
  def create_tag(attrs = {})
    Tag.create!({ name: "tag-#{SecureRandom.hex(4)}", created_by: SecureRandom.uuid }.merge(attrs))
  end

  describe "GET /api/v1/tags" do
    it "paginates and filters by name, without authentication" do
      matching = create_tag(name: "vegano")
      create_tag(name: "parrilla")

      get "/api/v1/tags", params: { per_page: 1, page: 1 }

      expect(response).to have_http_status(:ok)
      expect(json_response["data"].size).to eq(1)
      expect(json_response["meta"]).to include("per_page" => 1, "total_count" => 2)
      expect([ matching.name, "parrilla" ]).to include(json_response["data"].first["name"])
    end
  end

  describe "GET /api/v1/tags/:id" do
    it "returns the tag without authentication" do
      tag = create_tag

      get "/api/v1/tags/#{tag.id}"

      expect(response).to have_http_status(:ok)
      expect(json_response["id"]).to eq(tag.id)
    end

    it "returns 404 for a non-existent tag" do
      get "/api/v1/tags/999999"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/tags" do
    it "creates a tag" do
      consumer = create_consumer

      post "/api/v1/tags", params: { tag: { name: "sin_tacc" } }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:created)
      expect(Tag.find(json_response["id"]).created_by).to eq(consumer.id)
    end

    it "returns 422 when name is missing" do
      consumer = create_consumer

      post "/api/v1/tags", params: { tag: { name: nil } }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response["errors"]).to have_key("name")
    end

    it "returns 401 without authentication" do
      post "/api/v1/tags", params: { tag: { name: "sin_tacc" } }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "PATCH /api/v1/tags/:id" do
    it "updates the tag" do
      tag = create_tag
      consumer = create_consumer

      patch "/api/v1/tags/#{tag.id}", params: { tag: { name: "renamed" } }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:ok)
      expect(tag.reload.name).to eq("renamed")
    end

    it "returns 404 for a non-existent tag" do
      consumer = create_consumer

      patch "/api/v1/tags/999999", params: { tag: { name: "renamed" } }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:not_found)
    end

    it "returns 401 without authentication" do
      tag = create_tag

      patch "/api/v1/tags/#{tag.id}", params: { tag: { name: "renamed" } }

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 (not 404) for a non-existent id without authentication" do
      patch "/api/v1/tags/999999", params: { tag: { name: "renamed" } }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "DELETE /api/v1/tags/:id" do
    it "soft-deletes the tag" do
      tag = create_tag
      consumer = create_consumer

      delete "/api/v1/tags/#{tag.id}", headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:no_content)
      expect(Tag.unscoped.find(tag.id).deleted_at).to be_present
    end

    it "returns 404 for a non-existent tag" do
      consumer = create_consumer

      delete "/api/v1/tags/999999", headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:not_found)
    end

    it "returns 401 without authentication" do
      tag = create_tag

      delete "/api/v1/tags/#{tag.id}"

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 (not 404) for a non-existent id without authentication" do
      delete "/api/v1/tags/999999"

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
