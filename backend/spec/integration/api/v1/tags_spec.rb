require "swagger_helper"

RSpec.describe "Tags", type: :request do
  tag_list_item = {
    type: :object,
    properties: {
      id: { type: :integer },
      name: { type: :string }
    },
    required: %w[id name]
  }.freeze

  tag_extended = {
    type: :object,
    properties: tag_list_item[:properties].merge(
      created_at: { type: :string },
      updated_at: { type: :string }
    ),
    required: tag_list_item[:required] + %w[created_at updated_at]
  }.freeze

  path "/api/v1/tags" do
    get "Lists tags" do
      tags "Tags"
      produces "application/json"
      description "Public — no authentication required."
      parameter name: :page, in: :query, schema: { type: :integer }, required: false
      parameter name: :per_page, in: :query, schema: { type: :integer }, required: false

      response "200", "tags found" do
        schema type: :object,
          properties: {
            data: { type: :array, items: tag_list_item },
            meta: { "$ref" => "#/components/schemas/pagination_meta" }
          },
          required: %w[data meta]

        before { Tag.create!(name: "vegano", created_by: SecureRandom.uuid) }
        run_test!
      end
    end

    post "Creates a tag" do
      tags "Tags"
      security [ bearer_auth: [] ]
      consumes "application/json"
      produces "application/json"
      parameter name: :tag, in: :body, schema: {
        type: :object,
        properties: {
          tag: {
            type: :object,
            properties: { name: { type: :string } },
            required: %w[name]
          }
        },
        required: %w[tag]
      }

      response "201", "tag created" do
        schema tag_extended

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:tag) { { tag: { name: "sin_tacc" } } }
        run_test!
      end

      response "401", "not authenticated" do
        schema "$ref" => "#/components/schemas/error"

        let(:Authorization) { nil }

        let(:tag) { { tag: { name: "sin_tacc" } } }
        run_test!
      end

      response "422", "validation failed" do
        schema "$ref" => "#/components/schemas/validation_errors"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:tag) { { tag: { name: "" } } }
        run_test!
      end
    end
  end

  path "/api/v1/tags/{id}" do
    parameter name: :id, in: :path, schema: { type: :integer }

    get "Retrieves a tag" do
      tags "Tags"
      produces "application/json"
      description "Public — no authentication required."

      response "200", "tag found" do
        schema tag_extended

        let(:id) { Tag.create!(name: "vegano", created_by: SecureRandom.uuid).id }
        run_test!
      end

      response "404", "tag not found" do
        schema "$ref" => "#/components/schemas/error"

        let(:id) { 999_999 }
        run_test!
      end
    end

    patch "Updates a tag" do
      tags "Tags"
      security [ bearer_auth: [] ]
      consumes "application/json"
      produces "application/json"
      parameter name: :tag, in: :body, schema: {
        type: :object,
        properties: {
          tag: { type: :object, properties: { name: { type: :string } } }
        }
      }

      response "200", "tag updated" do
        schema tag_extended

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { Tag.create!(name: "vegano", created_by: SecureRandom.uuid).id }
        let(:tag) { { tag: { name: "vegetariano" } } }
        run_test!
      end

      response "401", "not authenticated" do
        schema "$ref" => "#/components/schemas/error"

        let(:Authorization) { nil }

        let(:id) { Tag.create!(name: "vegano", created_by: SecureRandom.uuid).id }
        let(:tag) { { tag: { name: "vegetariano" } } }
        run_test!
      end

      response "404", "tag not found" do
        schema "$ref" => "#/components/schemas/error"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { 999_999 }
        let(:tag) { { tag: { name: "vegetariano" } } }
        run_test!
      end

      response "422", "validation failed" do
        schema "$ref" => "#/components/schemas/validation_errors"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { Tag.create!(name: "vegano", created_by: SecureRandom.uuid).id }
        let(:tag) { { tag: { name: "" } } }
        run_test!
      end
    end

    delete "Soft-deletes a tag" do
      tags "Tags"
      security [ bearer_auth: [] ]

      response "204", "tag deleted" do
        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { Tag.create!(name: "vegano", created_by: SecureRandom.uuid).id }
        run_test!
      end

      response "401", "not authenticated" do
        schema "$ref" => "#/components/schemas/error"

        let(:Authorization) { nil }

        let(:id) { Tag.create!(name: "vegano", created_by: SecureRandom.uuid).id }
        run_test!
      end

      response "404", "tag not found" do
        schema "$ref" => "#/components/schemas/error"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { 999_999 }
        run_test!
      end
    end
  end
end
