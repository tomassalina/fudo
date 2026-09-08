require "rails_helper"

# ConsumerSetting only has updated_at/updated_by (see db/structure.sql), no
# created_at/created_by/deleted_at, and destroy is a real DELETE. All
# actions are scoped to the authenticated consumer's own setting.
RSpec.describe "Api::V1::ConsumerSettings", type: :request do
  def create_consumer_setting(attrs = {})
    consumer = attrs.delete(:consumer) || create_consumer
    ConsumerSetting.create!({ consumer: consumer, theme: "dark", notifications_enabled: true }.merge(attrs))
  end

  describe "GET /api/v1/consumer_settings" do
    it "paginates and scopes to the authenticated consumer's own setting" do
      consumer = create_consumer
      matching = create_consumer_setting(consumer: consumer)
      create_consumer_setting

      get "/api/v1/consumer_settings", params: { per_page: 5 }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:ok)
      ids = json_response["data"].map { |c| c["id"] }
      expect(ids).to eq([ matching.id ])
    end

    it "does not leak another consumer's setting via a consumer_id param" do
      consumer = create_consumer
      other = create_consumer
      create_consumer_setting(consumer: other)

      get "/api/v1/consumer_settings", params: { consumer_id: other.id }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:ok)
      expect(json_response["data"]).to eq([])
    end

    it "returns 401 without authentication" do
      get "/api/v1/consumer_settings"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/consumer_settings/:id" do
    it "returns the consumer setting" do
      consumer = create_consumer
      consumer_setting = create_consumer_setting(consumer: consumer)

      get "/api/v1/consumer_settings/#{consumer_setting.id}", headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:ok)
      expect(json_response["id"]).to eq(consumer_setting.id)
    end

    it "returns 404 for a non-existent consumer setting" do
      consumer = create_consumer

      get "/api/v1/consumer_settings/999999", headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 (not the setting) for another consumer's setting" do
      owner = create_consumer
      intruder = create_consumer
      consumer_setting = create_consumer_setting(consumer: owner)

      get "/api/v1/consumer_settings/#{consumer_setting.id}", headers: auth_headers_for(intruder)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/consumer_settings" do
    it "creates a consumer setting for the authenticated consumer and stamps updated_by" do
      consumer = create_consumer

      post "/api/v1/consumer_settings", params: { consumer_setting: { theme: "light" } }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:created)
      created = ConsumerSetting.find(json_response["id"])
      expect(created.updated_by).to eq(consumer.id)
      expect(created.consumer_id).to eq(consumer.id)
    end

    it "ignores a client-supplied consumer_id and always uses current_consumer" do
      consumer = create_consumer
      other = create_consumer

      post "/api/v1/consumer_settings", params: { consumer_setting: { consumer_id: other.id, theme: "light" } }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:created)
      expect(ConsumerSetting.find(json_response["id"]).consumer_id).to eq(consumer.id)
    end

    it "returns 422 for a duplicate consumer setting" do
      consumer = create_consumer
      create_consumer_setting(consumer: consumer)

      post "/api/v1/consumer_settings", params: { consumer_setting: { theme: "light" } }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response["errors"]).to have_key("consumer_id")
    end

    it "returns 401 without authentication" do
      post "/api/v1/consumer_settings", params: { consumer_setting: { theme: "light" } }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "PATCH /api/v1/consumer_settings/:id" do
    it "updates the consumer setting" do
      consumer = create_consumer
      consumer_setting = create_consumer_setting(consumer: consumer)

      patch "/api/v1/consumer_settings/#{consumer_setting.id}", params: { consumer_setting: { theme: "system" } }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:ok)
      expect(consumer_setting.reload.theme).to eq("system")
    end

    it "returns 404 for a non-existent consumer setting" do
      consumer = create_consumer

      patch "/api/v1/consumer_settings/999999", params: { consumer_setting: { theme: "system" } }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 (not the setting) when updating another consumer's setting" do
      owner = create_consumer
      intruder = create_consumer
      consumer_setting = create_consumer_setting(consumer: owner)

      patch "/api/v1/consumer_settings/#{consumer_setting.id}", params: { consumer_setting: { theme: "system" } }, headers: auth_headers_for(intruder)

      expect(response).to have_http_status(:not_found)
      expect(consumer_setting.reload.theme).not_to eq("system")
    end
  end

  describe "DELETE /api/v1/consumer_settings/:id" do
    it "hard-deletes the consumer setting" do
      consumer = create_consumer
      consumer_setting = create_consumer_setting(consumer: consumer)

      delete "/api/v1/consumer_settings/#{consumer_setting.id}", headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:no_content)
      expect(ConsumerSetting.where(id: consumer_setting.id)).not_to exist
    end

    it "returns 404 for a non-existent consumer setting" do
      consumer = create_consumer

      delete "/api/v1/consumer_settings/999999", headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 (not the setting) when deleting another consumer's setting" do
      owner = create_consumer
      intruder = create_consumer
      consumer_setting = create_consumer_setting(consumer: owner)

      delete "/api/v1/consumer_settings/#{consumer_setting.id}", headers: auth_headers_for(intruder)

      expect(response).to have_http_status(:not_found)
      expect(ConsumerSetting.where(id: consumer_setting.id)).to exist
    end
  end
end
