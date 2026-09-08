require "swagger_helper"

RSpec.describe "BusinessHours", type: :request do
  business_hour_item = {
    type: :object,
    properties: {
      id: { type: :integer },
      merchant_id: { type: :integer },
      day_of_week: { type: :string, enum: BusinessHour.day_of_weeks.keys },
      opens_at: { type: :string, nullable: true },
      closes_at: { type: :string, nullable: true },
      closed: { type: :boolean }
    },
    required: %w[id merchant_id day_of_week closed]
  }.freeze

  path "/api/v1/business_hours" do
    get "Lists business hours" do
      tags "BusinessHours"
      produces "application/json"
      description "Public — no authentication required."
      parameter name: :merchant_id, in: :query, schema: { type: :integer }, required: false,
        description: "Filter by merchant"
      parameter name: :page, in: :query, schema: { type: :integer }, required: false
      parameter name: :per_page, in: :query, schema: { type: :integer }, required: false

      response "200", "business hours found" do
        schema type: :object,
          properties: {
            data: { type: :array, items: business_hour_item },
            meta: { "$ref" => "#/components/schemas/pagination_meta" }
          },
          required: %w[data meta]

        let(:merchant) { create_merchant }
        before { BusinessHour.create!(merchant: merchant, day_of_week: "monday", opens_at: "09:00", closes_at: "18:00") }
        run_test!
      end
    end

    post "Creates a business hour" do
      tags "BusinessHours"
      security [ bearer_auth: [] ]
      consumes "application/json"
      produces "application/json"
      parameter name: :business_hour, in: :body, schema: {
        type: :object,
        properties: {
          business_hour: {
            type: :object,
            properties: {
              merchant_id: { type: :integer },
              day_of_week: { type: :string, enum: BusinessHour.day_of_weeks.keys },
              opens_at: { type: :string },
              closes_at: { type: :string },
              closed: { type: :boolean }
            },
            required: %w[merchant_id day_of_week]
          }
        },
        required: %w[business_hour]
      }

      response "201", "business hour created" do
        schema business_hour_item

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:merchant) { create_merchant }
        let(:business_hour) { { business_hour: { merchant_id: merchant.id, day_of_week: "monday", opens_at: "09:00", closes_at: "18:00" } } }
        run_test!
      end

      response "401", "not authenticated" do
        schema "$ref" => "#/components/schemas/error"

        let(:Authorization) { nil }
        let(:merchant) { create_merchant }
        let(:business_hour) { { business_hour: { merchant_id: merchant.id, day_of_week: "monday" } } }
        run_test!
      end

      response "422", "validation failed" do
        schema "$ref" => "#/components/schemas/validation_errors"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:merchant) { create_merchant }
        let(:business_hour) { { business_hour: { merchant_id: merchant.id, day_of_week: nil } } }
        run_test!
      end
    end
  end

  path "/api/v1/business_hours/{id}" do
    parameter name: :id, in: :path, schema: { type: :integer }

    get "Retrieves a business hour" do
      tags "BusinessHours"
      produces "application/json"
      description "Public — no authentication required."

      response "200", "business hour found" do
        schema business_hour_item

        let(:id) { BusinessHour.create!(merchant: create_merchant, day_of_week: "monday").id }
        run_test!
      end

      response "404", "business hour not found" do
        schema "$ref" => "#/components/schemas/error"

        let(:id) { 999_999 }
        run_test!
      end
    end

    patch "Updates a business hour" do
      tags "BusinessHours"
      security [ bearer_auth: [] ]
      consumes "application/json"
      produces "application/json"
      parameter name: :business_hour, in: :body, schema: {
        type: :object,
        properties: {
          business_hour: {
            type: :object,
            properties: {
              opens_at: { type: :string },
              closes_at: { type: :string },
              closed: { type: :boolean }
            }
          }
        }
      }

      response "200", "business hour updated" do
        schema business_hour_item

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { BusinessHour.create!(merchant: create_merchant, day_of_week: "monday").id }
        let(:business_hour) { { business_hour: { closed: true } } }
        run_test!
      end

      response "401", "not authenticated" do
        schema "$ref" => "#/components/schemas/error"

        let(:Authorization) { nil }
        let(:id) { BusinessHour.create!(merchant: create_merchant, day_of_week: "monday").id }
        let(:business_hour) { { business_hour: { closed: true } } }
        run_test!
      end

      response "404", "business hour not found" do
        schema "$ref" => "#/components/schemas/error"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { 999_999 }
        let(:business_hour) { { business_hour: { closed: true } } }
        run_test!
      end

      response "422", "validation failed" do
        schema "$ref" => "#/components/schemas/validation_errors"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { BusinessHour.create!(merchant: create_merchant, day_of_week: "monday").id }
        let(:business_hour) { { business_hour: { day_of_week: nil } } }
        run_test!
      end
    end

    delete "Deletes a business hour" do
      tags "BusinessHours"
      security [ bearer_auth: [] ]
      description "Hard delete — BusinessHour has no soft-delete column."

      response "204", "business hour deleted" do
        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { BusinessHour.create!(merchant: create_merchant, day_of_week: "monday").id }
        run_test!
      end

      response "401", "not authenticated" do
        schema "$ref" => "#/components/schemas/error"

        let(:Authorization) { nil }
        let(:id) { BusinessHour.create!(merchant: create_merchant, day_of_week: "monday").id }
        run_test!
      end

      response "404", "business hour not found" do
        schema "$ref" => "#/components/schemas/error"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { 999_999 }
        run_test!
      end
    end
  end
end
