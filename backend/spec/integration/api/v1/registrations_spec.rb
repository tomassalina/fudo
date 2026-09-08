require "swagger_helper"

RSpec.describe "Registrations", type: :request do
  consumer_item = {
    type: :object,
    properties: {
      id: { type: :string },
      email: { type: :string },
      first_name: { type: :string },
      last_name: { type: :string },
      phone: { type: :string, nullable: true }
    },
    required: %w[id email first_name last_name]
  }.freeze

  path "/api/v1/registrations" do
    post "Registers a new consumer" do
      tags "Registrations"
      consumes "application/json"
      produces "application/json"
      description "Self-registration — there is no authenticated actor yet. Returns the created " \
        "consumer plus a bearer token that can be used immediately on protected endpoints."
      parameter name: :registration, in: :body, schema: {
        type: :object,
        properties: {
          registration: {
            type: :object,
            properties: {
              email: { type: :string },
              password: { type: :string },
              password_confirmation: { type: :string },
              first_name: { type: :string },
              last_name: { type: :string },
              dni: { type: :string },
              phone: { type: :string }
            },
            required: %w[email password password_confirmation first_name last_name dni]
          }
        },
        required: %w[registration]
      }

      response "201", "consumer registered" do
        schema type: :object,
          properties: {
            consumer: consumer_item,
            token: { type: :string }
          },
          required: %w[consumer token]

        let(:registration) do
          {
            registration: {
              email: "new-consumer@example.com", password: "password123", password_confirmation: "password123",
              first_name: "Ada", last_name: "Lovelace", dni: SecureRandom.random_number(10**8).to_s
            }
          }
        end
        run_test!
      end

      response "422", "validation failed (duplicate email/dni, password mismatch, or missing fields)" do
        schema "$ref" => "#/components/schemas/validation_errors"

        let(:existing) { create_consumer(email: "duplicate@example.com") }
        let(:registration) do
          {
            registration: {
              email: existing.email, password: "password123", password_confirmation: "password123",
              first_name: "Ada", last_name: "Lovelace", dni: SecureRandom.random_number(10**8).to_s
            }
          }
        end
        run_test!
      end
    end
  end
end
