# frozen_string_literal: true

require "rails_helper"

RSpec.configure do |config|
  # Specify a root folder where Swagger JSON files are generated
  # NOTE: If you're using the rswag-api to serve API descriptions, you'll need
  # to ensure that it's configured to serve Swagger from the same folder
  config.openapi_root = Rails.root.join("swagger").to_s

  # Define one or more Swagger documents and provide global metadata for each one
  # When you run the 'rswag:specs:swaggerize' rake task, the complete Swagger will
  # be generated at the provided relative path under openapi_root
  # By default, the operations defined in spec files are added to the first
  # document below. You can override this behavior by adding a openapi_spec tag to the
  # the root example_group in your specs, e.g. describe '...', openapi_spec: 'v2/swagger.json'
  config.openapi_specs = {
    "v1/swagger.yaml" => {
      openapi: "3.0.1",
      info: {
        title: "Fudo Consumers API",
        version: "v1",
        description: "Consumer-facing API for the Fudo restaurant/bar/cafe discovery app: " \
          "catalog browsing, loyalty, visits, favorites, gifts, and natural-language search."
      },
      paths: {},
      servers: [
        {
          url: "http://localhost:3000",
          description: "Local development"
        }
      ],
      components: {
        securitySchemes: {
          bearer_auth: {
            type: :http,
            scheme: :bearer,
            bearerFormat: "JWT",
            description: "Consumer session token issued by POST /api/v1/registrations " \
              "or POST /api/v1/sessions. Sent as `Authorization: Bearer <token>`."
          }
        },
        schemas: {
          error: {
            type: :object,
            properties: {
              error: { type: :string }
            },
            required: %w[error]
          },
          validation_errors: {
            type: :object,
            properties: {
              errors: { type: :object }
            },
            required: %w[errors]
          },
          pagination_meta: {
            type: :object,
            properties: {
              current_page: { type: :integer },
              total_pages: { type: :integer },
              total_count: { type: :integer },
              per_page: { type: :integer }
            },
            required: %w[current_page total_pages total_count per_page]
          }
        }
      }
    }
  }

  # Specify the format of the output Swagger file when running 'rswag:specs:swaggerize'.
  # The openapi_specs configuration option has the filename including format in
  # the key, this may want to be changed to avoid putting yaml in json files.
  # Defaults to json. Accepts ':json' and ':yaml'.
  config.openapi_format = :yaml
end
