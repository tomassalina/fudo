require "swagger_helper"

RSpec.describe "VisitSummaries", type: :request do
  visit_summary_item = {
    type: :object,
    properties: {
      id: { type: :integer },
      consumer_id: { type: :string },
      merchant_id: { type: :integer },
      count: { type: :integer },
      current_tier: { type: :string, nullable: true },
      last_visit_at: { type: :string, nullable: true }
    },
    required: %w[id consumer_id merchant_id count]
  }.freeze

  path "/api/v1/visit_summaries" do
    get "Lists the authenticated consumer's visit summaries" do
      tags "VisitSummaries"
      security [ bearer_auth: [] ]
      produces "application/json"

      response "200", "visit summaries found" do
        schema type: :object,
          properties: {
            data: { type: :array, items: visit_summary_item },
            meta: { "$ref" => "#/components/schemas/pagination_meta" }
          },
          required: %w[data meta]

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        before { VisitSummary.create!(consumer: consumer, merchant: create_merchant, count: 3) }
        run_test!
      end

      response "401", "not authenticated" do
        schema "$ref" => "#/components/schemas/error"

        let(:Authorization) { nil }
        run_test!
      end
    end

    post "Creates a visit summary" do
      tags "VisitSummaries"
      security [ bearer_auth: [] ]
      consumes "application/json"
      produces "application/json"
      description "consumer_id always comes from the authenticated consumer, never from client input. " \
        "count/current_tier are NOT accepted either — both are computed server-side from the " \
        "consumer's real visits and the merchant's real loyalty_rules, so a consumer can't forge " \
        "their own loyalty tier/count."
      parameter name: :visit_summary, in: :body, schema: {
        type: :object,
        properties: {
          visit_summary: {
            type: :object,
            properties: {
              merchant_id: { type: :integer },
              last_visit_at: { type: :string }
            },
            required: %w[merchant_id]
          }
        },
        required: %w[visit_summary]
      }

      response "201", "visit summary created" do
        schema visit_summary_item

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:merchant) { create_merchant }
        let(:visit_summary) { { visit_summary: { merchant_id: merchant.id } } }
        run_test!
      end

      response "401", "not authenticated" do
        schema "$ref" => "#/components/schemas/error"

        let(:Authorization) { nil }
        let(:merchant) { create_merchant }
        let(:visit_summary) { { visit_summary: { merchant_id: merchant.id } } }
        run_test!
      end

      response "422", "validation failed" do
        schema "$ref" => "#/components/schemas/validation_errors"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        # merchant_id omitted on purpose — required, so this fails validation.
        let(:visit_summary) { { visit_summary: { last_visit_at: Time.current.iso8601 } } }
        run_test!
      end
    end
  end

  path "/api/v1/visit_summaries/{id}" do
    parameter name: :id, in: :path, schema: { type: :integer }

    get "Retrieves a visit summary" do
      tags "VisitSummaries"
      security [ bearer_auth: [] ]
      produces "application/json"
      description "Scoped to the authenticated consumer's own visit summaries — another consumer's summary 404s."

      response "200", "visit summary found" do
        schema visit_summary_item

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { VisitSummary.create!(consumer: consumer, merchant: create_merchant, count: 1).id }
        run_test!
      end

      response "401", "not authenticated" do
        schema "$ref" => "#/components/schemas/error"

        let(:Authorization) { nil }
        let(:id) { VisitSummary.create!(consumer: create_consumer, merchant: create_merchant, count: 1).id }
        run_test!
      end

      response "404", "visit summary not found" do
        schema "$ref" => "#/components/schemas/error"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { 999_999 }
        run_test!
      end
    end

    patch "Updates a visit summary" do
      tags "VisitSummaries"
      security [ bearer_auth: [] ]
      consumes "application/json"
      produces "application/json"
      parameter name: :visit_summary, in: :body, schema: {
        type: :object,
        properties: {
          visit_summary: {
            type: :object,
            properties: {
              merchant_id: { type: :integer },
              last_visit_at: { type: :string }
            }
          }
        }
      }

      response "200", "visit summary updated" do
        schema visit_summary_item

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { VisitSummary.create!(consumer: consumer, merchant: create_merchant, count: 1).id }
        let(:visit_summary) { { visit_summary: { last_visit_at: 1.day.ago.iso8601 } } }
        run_test!
      end

      response "401", "not authenticated" do
        schema "$ref" => "#/components/schemas/error"

        let(:Authorization) { nil }
        let(:id) { VisitSummary.create!(consumer: create_consumer, merchant: create_merchant, count: 1).id }
        let(:visit_summary) { { visit_summary: { last_visit_at: 1.day.ago.iso8601 } } }
        run_test!
      end

      response "404", "visit summary not found" do
        schema "$ref" => "#/components/schemas/error"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { 999_999 }
        let(:visit_summary) { { visit_summary: { last_visit_at: 1.day.ago.iso8601 } } }
        run_test!
      end

      response "422", "validation failed" do
        schema "$ref" => "#/components/schemas/validation_errors"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { VisitSummary.create!(consumer: consumer, merchant: create_merchant, count: 1).id }
        let(:visit_summary) { { visit_summary: { merchant_id: 999_999 } } }
        run_test!
      end
    end

    delete "Deletes a visit summary" do
      tags "VisitSummaries"
      security [ bearer_auth: [] ]
      description "Hard delete — VisitSummary has no soft-delete column."

      response "204", "visit summary deleted" do
        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { VisitSummary.create!(consumer: consumer, merchant: create_merchant, count: 1).id }
        run_test!
      end

      response "401", "not authenticated" do
        schema "$ref" => "#/components/schemas/error"

        let(:Authorization) { nil }
        let(:id) { VisitSummary.create!(consumer: create_consumer, merchant: create_merchant, count: 1).id }
        run_test!
      end

      response "404", "visit summary not found" do
        schema "$ref" => "#/components/schemas/error"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { 999_999 }
        run_test!
      end
    end
  end
end
