require "rails_helper"

# ConsumerSetting only has updated_at/updated_by (see db/structure.sql), no
# created_at/created_by/deleted_at, and destroy is a real DELETE.
RSpec.describe "Api::V1::ConsumerSettings", type: :request do
  def create_consumer_setting(attrs = {})
    consumer = attrs.delete(:consumer) || create_consumer
    ConsumerSetting.create!({ consumer: consumer, theme: "dark", notifications_enabled: true }.merge(attrs))
  end

  describe "GET /api/v1/consumer_settings" do
    it "paginates and filters by consumer_id" do
      consumer = create_consumer
      matching = create_consumer_setting(consumer: consumer)
      create_consumer_setting

      get "/api/v1/consumer_settings", params: { consumer_id: consumer.id, per_page: 5 }

      expect(response).to have_http_status(:ok)
      ids = json_response["data"].map { |c| c["id"] }
      expect(ids).to eq([ matching.id ])
    end
  end

  describe "GET /api/v1/consumer_settings/:id" do
    it "returns the consumer setting" do
      consumer_setting = create_consumer_setting

      get "/api/v1/consumer_settings/#{consumer_setting.id}"

      expect(response).to have_http_status(:ok)
      expect(json_response["id"]).to eq(consumer_setting.id)
    end

    it "returns 404 for a non-existent consumer setting" do
      get "/api/v1/consumer_settings/999999"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/consumer_settings" do
    it "creates a consumer setting and stamps updated_by" do
      consumer = create_consumer

      post "/api/v1/consumer_settings", params: { consumer_setting: { consumer_id: consumer.id, theme: "light" } }, headers: actor_headers

      expect(response).to have_http_status(:created)
      expect(ConsumerSetting.find(json_response["id"]).updated_by).to eq(actor_id)
    end

    it "returns 422 for a duplicate consumer_id" do
      existing = create_consumer_setting

      post "/api/v1/consumer_settings", params: { consumer_setting: { consumer_id: existing.consumer_id, theme: "light" } }, headers: actor_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response["errors"]).to have_key("consumer_id")
    end

    it "returns 400 without an X-Actor-Id header" do
      consumer = create_consumer

      post "/api/v1/consumer_settings", params: { consumer_setting: { consumer_id: consumer.id, theme: "light" } }

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "PATCH /api/v1/consumer_settings/:id" do
    it "updates the consumer setting" do
      consumer_setting = create_consumer_setting

      patch "/api/v1/consumer_settings/#{consumer_setting.id}", params: { consumer_setting: { theme: "system" } }, headers: actor_headers

      expect(response).to have_http_status(:ok)
      expect(consumer_setting.reload.theme).to eq("system")
    end

    it "returns 404 for a non-existent consumer setting" do
      patch "/api/v1/consumer_settings/999999", params: { consumer_setting: { theme: "system" } }, headers: actor_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/v1/consumer_settings/:id" do
    it "hard-deletes the consumer setting" do
      consumer_setting = create_consumer_setting

      delete "/api/v1/consumer_settings/#{consumer_setting.id}"

      expect(response).to have_http_status(:no_content)
      expect(ConsumerSetting.where(id: consumer_setting.id)).not_to exist
    end

    it "returns 404 for a non-existent consumer setting" do
      delete "/api/v1/consumer_settings/999999"

      expect(response).to have_http_status(:not_found)
    end
  end
end
