# Parses a free-text search query (e.g. "algo picante y barato en Palermo")
# into structured merchant filters by asking the Gemini API for JSON output
# constrained by a response schema. The returned shape matches the filters
# already supported by Merchant.search (see app/models/merchant.rb):
#
#   { "neighborhood" => String|nil, "type" => String|nil,
#     "tags" => Array<String>, "price_per_person" => Numeric|nil }
#
# Gemini REST API shape verified on 2026-09-08 against:
#   - https://ai.google.dev/api/generate-content
#   - https://ai.google.dev/gemini-api/docs/structured-output
#   - a live GET https://generativelanguage.googleapis.com/v1beta/models call
#     made against this project's own API key, confirming the endpoint,
#     available model ids, and that `key` is accepted as a query parameter.
#
# That research confirmed:
#   - Endpoint: POST https://generativelanguage.googleapis.com/v1beta/
#     models/{model}:generateContent
#   - Auth: API key as the `key` query parameter OR the `x-goog-api-key`
#     header (both accepted). This service uses the header so the key never
#     ends up embedded in a URI.
#   - generationConfig.responseMimeType: "application/json" plus
#     generationConfig.responseSchema (an OpenAPI-subset schema object) force
#     the model to emit JSON conforming to that schema.
#
# Net::HTTP (stdlib) is used for the single POST call per the project's
# convention of not adding a new HTTP client / provider SDK gem for a single
# request.
require "net/http"
require "uri"
require "json"

class SearchQueryParser
  # Raised when the Gemini API key is missing, or Gemini rejects it as
  # invalid/unauthorized. Never include the key itself in the message.
  class ConfigurationError < StandardError; end

  # Raised when the Gemini call fails (timeout, network error, non-2xx
  # response) or returns something that doesn't match the expected schema.
  # Never include raw provider response bodies in the message.
  class GeminiError < StandardError; end

  GEMINI_API_BASE = "https://generativelanguage.googleapis.com/v1beta/models".freeze

  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 15

  RESPONSE_SCHEMA = {
    type: "OBJECT",
    properties: {
      neighborhood: { type: "STRING", nullable: true },
      type: { type: "STRING", nullable: true, enum: Merchant.types.keys },
      tags: { type: "ARRAY", items: { type: "STRING" } },
      price_per_person: { type: "NUMBER", nullable: true }
    },
    required: %w[neighborhood type tags price_per_person]
  }.freeze

  SYSTEM_INSTRUCTION = <<~PROMPT.freeze
    You are a search query parser for a restaurant/bar/cafe discovery app.
    Extract structured filters from the user's free-text search query
    (which may be written in Spanish or English) and return ONLY the
    requested JSON fields.

    Rules:
    - "neighborhood": the neighborhood/area name mentioned in the query,
      exactly as written by the user, or null if none is mentioned.
    - "type": the kind of venue implied by the query, or null if unclear or
      not mentioned. Must be one of the allowed enum values.
    - "tags": short lowercase keywords describing cuisine, mood, dietary
      restrictions, or other descriptive attributes mentioned in the query
      (e.g. "picante", "vegetariano", "tranquilo"). Use an empty array if
      none apply.
    - "price_per_person": a numeric price-per-person estimate if the user
      gives one or implies a budget level (e.g. "barato" implies a low
      number), or null if price is not mentioned or explicitly irrelevant
      (e.g. "sin importar el precio").
  PROMPT

  def self.call(query_text)
    new(query_text).call
  end

  def initialize(query_text)
    @query_text = query_text
  end

  def call
    parse_structured_output(request_gemini)
  end

  private

  attr_reader :query_text

  def api_key
    key = ENV["GEMINI_API_KEY"]
    raise ConfigurationError, "Gemini API key is not configured" if key.blank?

    key
  end

  def model
    ENV.fetch("GEMINI_MODEL", "gemini-flash-latest")
  end

  def request_gemini
    uri = URI("#{GEMINI_API_BASE}/#{model}:generateContent")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = OPEN_TIMEOUT
    http.read_timeout = READ_TIMEOUT

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    # Auth via the `x-goog-api-key` header rather than the `?key=` query
    # param (both are accepted by the API) so the key never ends up in a
    # URI — cheap insurance against a future logging/APM/HTTP-instrumentation
    # library that captures outgoing request URLs.
    request["x-goog-api-key"] = api_key
    request.body = request_body.to_json

    begin
      http.request(request)
    rescue StandardError => e
      raise GeminiError, "Failed to reach the search parsing service (#{e.class})"
    end
  end

  def request_body
    {
      contents: [ { role: "user", parts: [ { text: query_text.to_s } ] } ],
      system_instruction: { parts: [ { text: SYSTEM_INSTRUCTION } ] },
      generationConfig: {
        responseMimeType: "application/json",
        responseSchema: RESPONSE_SCHEMA
      }
    }
  end

  def parse_structured_output(response)
    case response.code.to_i
    when 200
      extract_structured_output(response.body)
    when 401, 403
      raise ConfigurationError, "Gemini API rejected the configured API key"
    else
      raise GeminiError, "Search parsing service returned an error response"
    end
  end

  def extract_structured_output(body)
    payload = JSON.parse(body)
    text = payload.dig("candidates", 0, "content", "parts", 0, "text")
    raise GeminiError, "Search parsing service returned an unexpected response" if text.blank?

    structured = JSON.parse(text)
    validate_shape!(structured)
    structured
  rescue JSON::ParserError
    raise GeminiError, "Search parsing service returned an unexpected response"
  end

  def validate_shape!(structured)
    return if valid_shape?(structured)

    raise GeminiError, "Search parsing service returned an unexpected response"
  end

  # Checks both key presence AND value types. This matters beyond basic
  # correctness: an unvalidated value (e.g. a non-numeric "price_per_person"
  # or a "type" outside the enum) would otherwise flow straight into
  # Merchant.search's raw SQL bind and blow up as a StatementInvalid deep
  # inside ActiveRecord instead of failing here with a clear GeminiError.
  def valid_shape?(structured)
    structured.is_a?(Hash) &&
      valid_optional_string?(structured["neighborhood"]) &&
      valid_type?(structured["type"]) &&
      valid_tags?(structured["tags"]) &&
      valid_optional_number?(structured["price_per_person"])
  end

  def valid_optional_string?(value)
    value.nil? || value.is_a?(String)
  end

  def valid_type?(value)
    value.nil? || (value.is_a?(String) && Merchant.types.key?(value))
  end

  def valid_tags?(value)
    value.is_a?(Array) && value.all? { |tag| tag.is_a?(String) }
  end

  def valid_optional_number?(value)
    value.nil? || value.is_a?(Numeric)
  end
end
