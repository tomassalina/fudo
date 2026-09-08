require "rails_helper"

RSpec.describe "Api::V1::Favorites", type: :request do
  def create_favorite(attrs = {})
    consumer = attrs.delete(:consumer) || create_consumer
    merchant = attrs.delete(:merchant) || create_merchant
    Favorite.create!({ consumer: consumer, merchant: merchant, created_by: SecureRandom.uuid }.merge(attrs))
  end

  describe "GET /api/v1/favorites" do
    it "paginates and scopes to the authenticated consumer's own favorites" do
      consumer = create_consumer
      matching = create_favorite(consumer: consumer)
      create_favorite

      get "/api/v1/favorites", params: { per_page: 5 }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:ok)
      ids = json_response["data"].map { |f| f["id"] }
      expect(ids).to eq([ matching.id ])
    end

    it "does not leak another consumer's favorites via a consumer_id param" do
      consumer = create_consumer
      other = create_consumer
      create_favorite(consumer: other)

      get "/api/v1/favorites", params: { consumer_id: other.id }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:ok)
      expect(json_response["data"]).to eq([])
    end

    it "returns 401 without authentication" do
      get "/api/v1/favorites"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/favorites/:id" do
    it "returns the favorite" do
      consumer = create_consumer
      favorite = create_favorite(consumer: consumer)

      get "/api/v1/favorites/#{favorite.id}", headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:ok)
      expect(json_response["id"]).to eq(favorite.id)
    end

    it "returns 404 for a non-existent favorite" do
      consumer = create_consumer

      get "/api/v1/favorites/999999", headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 (not the favorite) for another consumer's favorite" do
      owner = create_consumer
      intruder = create_consumer
      favorite = create_favorite(consumer: owner)

      get "/api/v1/favorites/#{favorite.id}", headers: auth_headers_for(intruder)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/favorites" do
    it "creates a favorite owned by the authenticated consumer" do
      consumer = create_consumer
      merchant = create_merchant

      post "/api/v1/favorites", params: { favorite: { merchant_id: merchant.id } }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:created)
      created = Favorite.find(json_response["id"])
      expect(created.created_by).to eq(consumer.id)
      expect(created.consumer_id).to eq(consumer.id)
    end

    it "ignores a client-supplied consumer_id and always uses current_consumer" do
      consumer = create_consumer
      other = create_consumer
      merchant = create_merchant

      post "/api/v1/favorites", params: { favorite: { consumer_id: other.id, merchant_id: merchant.id } }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:created)
      expect(Favorite.find(json_response["id"]).consumer_id).to eq(consumer.id)
    end

    it "returns 422 for a duplicate consumer/merchant pair" do
      consumer = create_consumer
      favorite = create_favorite(consumer: consumer)

      post "/api/v1/favorites", params: { favorite: { merchant_id: favorite.merchant_id } }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response["errors"]).to have_key("merchant_id")
    end

    it "returns 401 without authentication" do
      merchant = create_merchant

      post "/api/v1/favorites", params: { favorite: { merchant_id: merchant.id } }

      expect(response).to have_http_status(:unauthorized)
    end

    # Rails' own uniqueness validator queries via `klass.unscoped`
    # (active_record/validations/uniqueness.rb), so it already sees a
    # soft-deleted row through `default_scope` and blocks a plain
    # re-favorite with a 422 — the DB's unconditional unique index on
    # (consumer_id, merchant_id) is never reached that way. What it does NOT
    # protect against is a race: two concurrent creates can both pass
    # validation before either has committed, so the second INSERT can still
    # hit the DB constraint directly. Simulate that race by bypassing model
    # validation, and confirm the base controller turns that into a 409
    # instead of an unhandled 500.
    it "returns 409 instead of a raw 500 if a duplicate reaches the DB unique index" do
      consumer = create_consumer
      existing = create_favorite(consumer: consumer)
      allow_any_instance_of(Favorite).to receive(:valid?).and_return(true)

      post "/api/v1/favorites", params: { favorite: { merchant_id: existing.merchant_id } }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:conflict)
      expect(json_response["error"]).to eq("Resource already exists")
    end

    # The DB's unique index on (consumer_id, merchant_id) is NOT partial —
    # it applies to soft-deleted rows too (see db/structure.sql). Before the
    # revive-on-recreate fix, unfavoriting and then re-favoriting the same
    # merchant would hit that index directly on every attempt and 409
    # forever, since the default_scope hides the soft-deleted row from the
    # uniqueness *validation* but not from Postgres.
    it "revives the same soft-deleted favorite instead of 409ing when re-favoriting after unfavorite" do
      consumer = create_consumer
      merchant = create_merchant
      original = create_favorite(consumer: consumer, merchant: merchant)
      original.soft_delete!(consumer.id)

      post "/api/v1/favorites", params: { favorite: { merchant_id: merchant.id } }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:created)
      expect(json_response["id"]).to eq(original.id)
      revived = Favorite.find(original.id)
      expect(revived.deleted_at).to be_nil
      expect(revived.deleted_by).to be_nil
      expect(revived.created_by).to eq(consumer.id)
    end
  end

  describe "PATCH /api/v1/favorites/:id" do
    it "updates the favorite" do
      consumer = create_consumer
      favorite = create_favorite(consumer: consumer)
      other_merchant = create_merchant

      patch "/api/v1/favorites/#{favorite.id}", params: { favorite: { merchant_id: other_merchant.id } }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:ok)
      expect(favorite.reload.merchant_id).to eq(other_merchant.id)
    end

    it "returns 404 for a non-existent favorite" do
      consumer = create_consumer

      patch "/api/v1/favorites/999999", params: { favorite: { merchant_id: create_merchant.id } }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 (not the favorite) when updating another consumer's favorite" do
      owner = create_consumer
      intruder = create_consumer
      favorite = create_favorite(consumer: owner)
      other_merchant = create_merchant

      patch "/api/v1/favorites/#{favorite.id}", params: { favorite: { merchant_id: other_merchant.id } }, headers: auth_headers_for(intruder)

      expect(response).to have_http_status(:not_found)
      expect(favorite.reload.merchant_id).not_to eq(other_merchant.id)
    end
  end

  describe "DELETE /api/v1/favorites/:id" do
    it "soft-deletes the favorite" do
      consumer = create_consumer
      favorite = create_favorite(consumer: consumer)

      delete "/api/v1/favorites/#{favorite.id}", headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:no_content)
      expect(Favorite.unscoped.find(favorite.id).deleted_at).to be_present
    end

    it "returns 404 for a non-existent favorite" do
      consumer = create_consumer

      delete "/api/v1/favorites/999999", headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 (not the favorite) when deleting another consumer's favorite" do
      owner = create_consumer
      intruder = create_consumer
      favorite = create_favorite(consumer: owner)

      delete "/api/v1/favorites/#{favorite.id}", headers: auth_headers_for(intruder)

      expect(response).to have_http_status(:not_found)
      expect(Favorite.unscoped.find(favorite.id).deleted_at).to be_nil
    end
  end
end
