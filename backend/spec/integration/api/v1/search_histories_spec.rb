require "swagger_helper"

RSpec.describe "SearchHistories", type: :request do
  search_history_list_item = {
    type: :object,
    properties: {
      id: { type: :integer },
      consumer_id: { type: :string },
      query_text: { type: :string },
      created_at: { type: :string }
    },
    required: %w[id consumer_id query_text created_at]
  }.freeze

  search_history_extended = {
    type: :object,
    properties: search_history_list_item[:properties].merge(
      structured_output: { type: :object, nullable: true },
      updated_at: { type: :string }
    ),
    required: search_history_list_item[:required] + %w[updated_at]
  }.freeze

  path "/api/v1/search_histories" do
    get "Lists the authenticated consumer's search history" do
      tags "SearchHistories"
      security [ bearer_auth: [] ]
      produces "application/json"

      response "200", "search history found" do
        schema type: :object,
          properties: {
            data: { type: :array, items: search_history_list_item },
            meta: { "$ref" => "#/components/schemas/pagination_meta" }
          },
          required: %w[data meta]

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        before { consumer.search_histories.create!(query_text: "pizza", created_by: consumer.id) }
        run_test!
      end

      response "401", "not authenticated" do
        schema "$ref" => "#/components/schemas/error"

        let(:Authorization) { nil }
        run_test!
      end
    end

    post "Creates a search history entry" do
      tags "SearchHistories"
      security [ bearer_auth: [] ]
      consumes "application/json"
      produces "application/json"
      description "consumer_id always comes from the authenticated consumer. Note: the natural-language " \
        "search endpoint (POST /api/v1/search) already creates these automatically — this endpoint lets a " \
        "client record an entry directly."
      parameter name: :search_history, in: :body, schema: {
        type: :object,
        properties: {
          search_history: {
            type: :object,
            properties: {
              query_text: { type: :string },
              structured_output: { type: :object }
            },
            required: %w[query_text]
          }
        },
        required: %w[search_history]
      }

      response "201", "search history entry created" do
        schema search_history_extended

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:search_history) { { search_history: { query_text: "pizza en Palermo" } } }
        run_test!
      end

      response "401", "not authenticated" do
        schema "$ref" => "#/components/schemas/error"

        let(:Authorization) { nil }
        let(:search_history) { { search_history: { query_text: "pizza" } } }
        run_test!
      end

      response "422", "validation failed" do
        schema "$ref" => "#/components/schemas/validation_errors"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:search_history) { { search_history: { query_text: "" } } }
        run_test!
      end
    end
  end

  path "/api/v1/search_histories/{id}" do
    parameter name: :id, in: :path, schema: { type: :integer }

    get "Retrieves a search history entry" do
      tags "SearchHistories"
      security [ bearer_auth: [] ]
      produces "application/json"
      description "Scoped to the authenticated consumer's own entries — another consumer's entry 404s."

      response "200", "search history entry found" do
        schema search_history_extended

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { consumer.search_histories.create!(query_text: "pizza", created_by: consumer.id).id }
        run_test!
      end

      response "401", "not authenticated" do
        schema "$ref" => "#/components/schemas/error"

        let(:Authorization) { nil }
        let(:id) do
          consumer = create_consumer
          consumer.search_histories.create!(query_text: "pizza", created_by: consumer.id).id
        end
        run_test!
      end

      response "404", "search history entry not found" do
        schema "$ref" => "#/components/schemas/error"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { 999_999 }
        run_test!
      end
    end

    patch "Updates a search history entry" do
      tags "SearchHistories"
      security [ bearer_auth: [] ]
      consumes "application/json"
      produces "application/json"
      parameter name: :search_history, in: :body, schema: {
        type: :object,
        properties: {
          search_history: {
            type: :object,
            properties: { query_text: { type: :string } }
          }
        }
      }

      response "200", "search history entry updated" do
        schema search_history_extended

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { consumer.search_histories.create!(query_text: "pizza", created_by: consumer.id).id }
        let(:search_history) { { search_history: { query_text: "sushi" } } }
        run_test!
      end

      response "401", "not authenticated" do
        schema "$ref" => "#/components/schemas/error"

        let(:Authorization) { nil }
        let(:id) do
          consumer = create_consumer
          consumer.search_histories.create!(query_text: "pizza", created_by: consumer.id).id
        end
        let(:search_history) { { search_history: { query_text: "sushi" } } }
        run_test!
      end

      response "404", "search history entry not found" do
        schema "$ref" => "#/components/schemas/error"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { 999_999 }
        let(:search_history) { { search_history: { query_text: "sushi" } } }
        run_test!
      end

      response "422", "validation failed" do
        schema "$ref" => "#/components/schemas/validation_errors"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { consumer.search_histories.create!(query_text: "pizza", created_by: consumer.id).id }
        let(:search_history) { { search_history: { query_text: "" } } }
        run_test!
      end
    end

    delete "Soft-deletes a search history entry" do
      tags "SearchHistories"
      security [ bearer_auth: [] ]

      response "204", "search history entry deleted" do
        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { consumer.search_histories.create!(query_text: "pizza", created_by: consumer.id).id }
        run_test!
      end

      response "401", "not authenticated" do
        schema "$ref" => "#/components/schemas/error"

        let(:Authorization) { nil }
        let(:id) do
          consumer = create_consumer
          consumer.search_histories.create!(query_text: "pizza", created_by: consumer.id).id
        end
        run_test!
      end

      response "404", "search history entry not found" do
        schema "$ref" => "#/components/schemas/error"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { 999_999 }
        run_test!
      end
    end
  end
end
