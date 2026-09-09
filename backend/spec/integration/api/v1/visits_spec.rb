require "swagger_helper"

RSpec.describe "Visits", type: :request do
  visit_list_item = {
    type: :object,
    properties: {
      id: { type: :integer },
      consumer_id: { type: :string },
      merchant_id: { type: :integer },
      amount: { type: :string },
      visited_at: { type: :string },
      reward_applied: { type: :boolean }
    },
    required: %w[id consumer_id merchant_id amount visited_at reward_applied]
  }.freeze

  visit_extended = {
    type: :object,
    properties: visit_list_item[:properties].merge(
      reward_description_snapshot: { type: :string, nullable: true },
      created_at: { type: :string },
      updated_at: { type: :string }
    ),
    required: visit_list_item[:required] + %w[created_at updated_at]
  }.freeze

  path "/api/v1/visits" do
    get "Lists the authenticated consumer's visits" do
      tags "Visits"
      security [ bearer_auth: [] ]
      produces "application/json"

      response "200", "visits found" do
        schema type: :object,
          properties: {
            data: { type: :array, items: visit_list_item },
            meta: { "$ref" => "#/components/schemas/pagination_meta" }
          },
          required: %w[data meta]

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        before { Visit.create!(consumer: consumer, merchant: create_merchant, amount: 5000, visited_at: Time.current, created_by: consumer.id) }
        run_test!
      end

      response "401", "not authenticated" do
        schema "$ref" => "#/components/schemas/error"

        let(:Authorization) { nil }
        run_test!
      end
    end

    post "Creates a visit" do
      tags "Visits"
      security [ bearer_auth: [] ]
      consumes "application/json"
      produces "application/json"
      description "consumer_id always comes from the authenticated consumer. reward_applied always " \
        "starts false and reward fields are never client-settable — there is no staff flow to apply " \
        "loyalty rewards yet (accepted MVP limitation)."
      parameter name: :visit, in: :body, schema: {
        type: :object,
        properties: {
          visit: {
            type: :object,
            properties: {
              merchant_id: { type: :integer },
              amount: { type: :number },
              visited_at: { type: :string }
            },
            required: %w[merchant_id amount visited_at]
          }
        },
        required: %w[visit]
      }

      response "201", "visit created" do
        schema visit_extended

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:merchant) { create_merchant }
        let(:visit) { { visit: { merchant_id: merchant.id, amount: 5000, visited_at: Time.current.iso8601 } } }
        run_test!
      end

      response "401", "not authenticated" do
        schema "$ref" => "#/components/schemas/error"

        let(:Authorization) { nil }
        let(:merchant) { create_merchant }
        let(:visit) { { visit: { merchant_id: merchant.id, amount: 5000, visited_at: Time.current.iso8601 } } }
        run_test!
      end

      response "422", "validation failed" do
        schema "$ref" => "#/components/schemas/validation_errors"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:merchant) { create_merchant }
        let(:visit) { { visit: { merchant_id: merchant.id, amount: -1, visited_at: Time.current.iso8601 } } }
        run_test!
      end
    end
  end

  path "/api/v1/visits/{id}" do
    parameter name: :id, in: :path, schema: { type: :integer }

    get "Retrieves a visit" do
      tags "Visits"
      security [ bearer_auth: [] ]
      produces "application/json"
      description "Scoped to the authenticated consumer's own visits — another consumer's visit 404s."

      response "200", "visit found" do
        schema visit_extended

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { Visit.create!(consumer: consumer, merchant: create_merchant, amount: 5000, visited_at: Time.current, created_by: consumer.id).id }
        run_test!
      end

      response "401", "not authenticated" do
        schema "$ref" => "#/components/schemas/error"

        let(:Authorization) { nil }
        let(:id) do
          consumer = create_consumer
          Visit.create!(consumer: consumer, merchant: create_merchant, amount: 5000, visited_at: Time.current, created_by: consumer.id).id
        end
        run_test!
      end

      response "404", "visit not found" do
        schema "$ref" => "#/components/schemas/error"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { 999_999 }
        run_test!
      end
    end

    patch "Updates a visit" do
      tags "Visits"
      security [ bearer_auth: [] ]
      consumes "application/json"
      produces "application/json"
      description "merchant_id/amount are NOT accepted here — a visit's merchant and charged amount " \
        "are immutable once recorded, only visited_at can still be corrected after creation."
      parameter name: :visit, in: :body, schema: {
        type: :object,
        properties: {
          visit: {
            type: :object,
            properties: {
              visited_at: { type: :string }
            }
          }
        }
      }

      response "200", "visit updated" do
        schema visit_extended

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { Visit.create!(consumer: consumer, merchant: create_merchant, amount: 5000, visited_at: Time.current, created_by: consumer.id).id }
        let(:visit) { { visit: { visited_at: 1.day.ago.iso8601 } } }
        run_test!
      end

      response "401", "not authenticated" do
        schema "$ref" => "#/components/schemas/error"

        let(:Authorization) { nil }
        let(:id) do
          consumer = create_consumer
          Visit.create!(consumer: consumer, merchant: create_merchant, amount: 5000, visited_at: Time.current, created_by: consumer.id).id
        end
        let(:visit) { { visit: { visited_at: 1.day.ago.iso8601 } } }
        run_test!
      end

      response "404", "visit not found" do
        schema "$ref" => "#/components/schemas/error"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { 999_999 }
        let(:visit) { { visit: { visited_at: 1.day.ago.iso8601 } } }
        run_test!
      end

      response "422", "validation failed" do
        schema "$ref" => "#/components/schemas/validation_errors"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { Visit.create!(consumer: consumer, merchant: create_merchant, amount: 5000, visited_at: Time.current, created_by: consumer.id).id }
        let(:visit) { { visit: { visited_at: nil } } }
        run_test!
      end
    end

    delete "Soft-deletes a visit" do
      tags "Visits"
      security [ bearer_auth: [] ]

      response "204", "visit deleted" do
        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { Visit.create!(consumer: consumer, merchant: create_merchant, amount: 5000, visited_at: Time.current, created_by: consumer.id).id }
        run_test!
      end

      response "401", "not authenticated" do
        schema "$ref" => "#/components/schemas/error"

        let(:Authorization) { nil }
        let(:id) do
          consumer = create_consumer
          Visit.create!(consumer: consumer, merchant: create_merchant, amount: 5000, visited_at: Time.current, created_by: consumer.id).id
        end
        run_test!
      end

      response "404", "visit not found" do
        schema "$ref" => "#/components/schemas/error"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { 999_999 }
        run_test!
      end
    end
  end
end
