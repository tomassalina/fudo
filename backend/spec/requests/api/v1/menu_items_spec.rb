require "rails_helper"

RSpec.describe "Api::V1::MenuItems", type: :request do
  def create_menu_item(attrs = {})
    merchant = attrs.delete(:merchant) || create_merchant
    MenuItem.create!({
      merchant: merchant, name: "Item #{SecureRandom.hex(4)}", price: 100,
      currency: "usd", created_by: SecureRandom.uuid
    }.merge(attrs))
  end

  describe "GET /api/v1/menu_items" do
    it "paginates and filters by merchant_id, without authentication" do
      merchant = create_merchant
      matching = create_menu_item(merchant: merchant)
      create_menu_item

      get "/api/v1/menu_items", params: { merchant_id: merchant.id, per_page: 5 }

      expect(response).to have_http_status(:ok)
      ids = json_response["data"].map { |m| m["id"] }
      expect(ids).to eq([ matching.id ])
      expect(json_response["meta"]).to include("current_page" => 1, "total_count" => 1)
    end

    it "keeps the :list payload small — no description/tags/timestamps" do
      create_menu_item

      get "/api/v1/menu_items"

      expect(response).to have_http_status(:ok)
      row = json_response["data"].first
      expect(row.keys).to include("name", "price", "currency")
      expect(row.keys).not_to include("description", "tags", "created_at", "updated_at")
    end
  end

  describe "GET /api/v1/menu_items/:id" do
    it "returns the menu item without authentication" do
      menu_item = create_menu_item

      get "/api/v1/menu_items/#{menu_item.id}"

      expect(response).to have_http_status(:ok)
      expect(json_response["id"]).to eq(menu_item.id)
    end

    it "returns 404 for a non-existent menu item" do
      get "/api/v1/menu_items/999999"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/menu_items" do
    it "creates a menu item" do
      merchant = create_merchant
      consumer = create_consumer

      post "/api/v1/menu_items",
        params: { menu_item: { merchant_id: merchant.id, name: "Milanesa", price: 5000, currency: "ars" } },
        headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:created)
      expect(MenuItem.find(json_response["id"]).created_by).to eq(consumer.id)
    end

    it "returns 422 when required fields are missing" do
      merchant = create_merchant
      consumer = create_consumer

      post "/api/v1/menu_items",
        params: { menu_item: { merchant_id: merchant.id, name: nil, price: 5000, currency: "ars" } },
        headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response["errors"]).to have_key("name")
    end

    it "returns 401 without authentication" do
      merchant = create_merchant

      post "/api/v1/menu_items",
        params: { menu_item: { merchant_id: merchant.id, name: "Milanesa", price: 5000, currency: "ars" } }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "PATCH /api/v1/menu_items/:id" do
    it "updates the menu item" do
      menu_item = create_menu_item
      consumer = create_consumer

      patch "/api/v1/menu_items/#{menu_item.id}", params: { menu_item: { price: 999 } }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:ok)
      expect(menu_item.reload.price.to_f).to eq(999.0)
    end

    it "returns 404 for a non-existent menu item" do
      consumer = create_consumer

      patch "/api/v1/menu_items/999999", params: { menu_item: { price: 999 } }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:not_found)
    end

    it "returns 401 without authentication" do
      menu_item = create_menu_item

      patch "/api/v1/menu_items/#{menu_item.id}", params: { menu_item: { price: 999 } }

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 (not 404) for a non-existent id without authentication" do
      patch "/api/v1/menu_items/999999", params: { menu_item: { price: 999 } }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "DELETE /api/v1/menu_items/:id" do
    it "soft-deletes the menu item" do
      menu_item = create_menu_item
      consumer = create_consumer

      delete "/api/v1/menu_items/#{menu_item.id}", headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:no_content)
      expect(MenuItem.unscoped.find(menu_item.id).deleted_at).to be_present
    end

    it "returns 404 for a non-existent menu item" do
      consumer = create_consumer

      delete "/api/v1/menu_items/999999", headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:not_found)
    end

    it "returns 401 without authentication" do
      menu_item = create_menu_item

      delete "/api/v1/menu_items/#{menu_item.id}"

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 (not 404) for a non-existent id without authentication" do
      delete "/api/v1/menu_items/999999"

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
