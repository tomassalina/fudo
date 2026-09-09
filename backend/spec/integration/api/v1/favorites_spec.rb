require "swagger_helper"

RSpec.describe "Favorites", type: :request do
  favorite_item = {
    type: :object,
    properties: {
      id: { type: :integer },
      consumer_id: { type: :string },
      merchant_id: { type: :integer },
      created_at: { type: :string }
    },
    required: %w[id consumer_id merchant_id created_at]
  }.freeze

  path "/api/v1/favorites" do
    get "Lists the authenticated consumer's favorites" do
      tags "Favorites"
      security [ bearer_auth: [] ]
      produces "application/json"

      response "200", "favorites found" do
        schema type: :object,
          properties: {
            data: { type: :array, items: favorite_item },
            meta: { "$ref" => "#/components/schemas/pagination_meta" }
          },
          required: %w[data meta]

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        before { Favorite.create!(consumer: consumer, merchant: create_merchant, created_by: consumer.id) }
        run_test!
      end

      response "401", "not authenticated" do
        schema "$ref" => "#/components/schemas/error"

        let(:Authorization) { nil }
        run_test!
      end
    end

    post "Creates a favorite" do
      tags "Favorites"
      security [ bearer_auth: [] ]
      consumes "application/json"
      produces "application/json"
      description "consumer_id always comes from the authenticated consumer, never from client input."
      parameter name: :favorite, in: :body, schema: {
        type: :object,
        properties: {
          favorite: {
            type: :object,
            properties: { merchant_id: { type: :integer } },
            required: %w[merchant_id]
          }
        },
        required: %w[favorite]
      }

      response "201", "favorite created" do
        schema favorite_item

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:merchant) { create_merchant }
        let(:favorite) { { favorite: { merchant_id: merchant.id } } }
        run_test!
      end

      response "401", "not authenticated" do
        schema "$ref" => "#/components/schemas/error"

        let(:Authorization) { nil }
        let(:merchant) { create_merchant }
        let(:favorite) { { favorite: { merchant_id: merchant.id } } }
        run_test!
      end

      response "422", "duplicate consumer/merchant pair" do
        schema "$ref" => "#/components/schemas/validation_errors"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:merchant) { create_merchant }
        before { Favorite.create!(consumer: consumer, merchant: merchant, created_by: consumer.id) }
        let(:favorite) { { favorite: { merchant_id: merchant.id } } }
        run_test!
      end

      response "409", "duplicate reached the DB unique index directly (race condition)" do
        schema "$ref" => "#/components/schemas/error"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:merchant) { create_merchant }
        before do
          Favorite.create!(consumer: consumer, merchant: merchant, created_by: consumer.id)
          allow_any_instance_of(Favorite).to receive(:valid?).and_return(true)
        end
        let(:favorite) { { favorite: { merchant_id: merchant.id } } }
        run_test!
      end
    end
  end

  path "/api/v1/favorites/{id}" do
    parameter name: :id, in: :path, schema: { type: :integer }

    get "Retrieves a favorite" do
      tags "Favorites"
      security [ bearer_auth: [] ]
      produces "application/json"
      description "Scoped to the authenticated consumer's own favorites — another consumer's favorite 404s."

      response "200", "favorite found" do
        schema favorite_item

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { Favorite.create!(consumer: consumer, merchant: create_merchant, created_by: consumer.id).id }
        run_test!
      end

      response "401", "not authenticated" do
        schema "$ref" => "#/components/schemas/error"

        let(:Authorization) { nil }
        let(:id) do
          consumer = create_consumer
          Favorite.create!(consumer: consumer, merchant: create_merchant, created_by: consumer.id).id
        end
        run_test!
      end

      response "404", "favorite not found" do
        schema "$ref" => "#/components/schemas/error"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { 999_999 }
        run_test!
      end
    end

    patch "Updates a favorite" do
      tags "Favorites"
      security [ bearer_auth: [] ]
      consumes "application/json"
      produces "application/json"
      parameter name: :favorite, in: :body, schema: {
        type: :object,
        properties: {
          favorite: {
            type: :object,
            properties: { merchant_id: { type: :integer } }
          }
        }
      }

      response "200", "favorite updated" do
        schema favorite_item

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { Favorite.create!(consumer: consumer, merchant: create_merchant, created_by: consumer.id).id }
        let(:other_merchant) { create_merchant }
        let(:favorite) { { favorite: { merchant_id: other_merchant.id } } }
        run_test!
      end

      response "401", "not authenticated" do
        schema "$ref" => "#/components/schemas/error"

        let(:Authorization) { nil }
        let(:id) do
          consumer = create_consumer
          Favorite.create!(consumer: consumer, merchant: create_merchant, created_by: consumer.id).id
        end
        let(:favorite) { { favorite: { merchant_id: create_merchant.id } } }
        run_test!
      end

      response "404", "favorite not found" do
        schema "$ref" => "#/components/schemas/error"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { 999_999 }
        let(:favorite) { { favorite: { merchant_id: create_merchant.id } } }
        run_test!
      end
    end

    delete "Soft-deletes a favorite" do
      tags "Favorites"
      security [ bearer_auth: [] ]

      response "204", "favorite deleted" do
        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { Favorite.create!(consumer: consumer, merchant: create_merchant, created_by: consumer.id).id }
        run_test!
      end

      response "401", "not authenticated" do
        schema "$ref" => "#/components/schemas/error"

        let(:Authorization) { nil }
        let(:id) do
          consumer = create_consumer
          Favorite.create!(consumer: consumer, merchant: create_merchant, created_by: consumer.id).id
        end
        run_test!
      end

      response "404", "favorite not found" do
        schema "$ref" => "#/components/schemas/error"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { 999_999 }
        run_test!
      end
    end
  end
end
