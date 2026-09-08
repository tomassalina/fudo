require "swagger_helper"

RSpec.describe "Sessions", type: :request do
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

  path "/api/v1/sessions" do
    post "Logs in a consumer" do
      tags "Sessions"
      consumes "application/json"
      produces "application/json"
      description "Rate-limited (see Rack::Attack) beyond a small number of failed attempts per email/IP."
      parameter name: :session, in: :body, schema: {
        type: :object,
        properties: {
          email: { type: :string },
          password: { type: :string }
        },
        required: %w[email password]
      }

      response "200", "session created" do
        schema type: :object,
          properties: {
            consumer: consumer_item,
            token: { type: :string }
          },
          required: %w[consumer token]

        let(:consumer) { create_consumer(password: "password123") }
        let(:session) { { email: consumer.email, password: "password123" } }
        run_test!
      end

      response "401", "invalid email or password" do
        schema "$ref" => "#/components/schemas/error"
        description "Deliberately generic message — never reveals whether the email exists."

        let(:session) { { email: "nobody@example.com", password: "wrong-password" } }
        run_test!
      end
    end
  end
end
