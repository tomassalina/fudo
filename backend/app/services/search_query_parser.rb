# Parses a free-text search query (e.g. "algo picante y barato en Palermo")
# into structured merchant filters by asking the Gemini API for JSON output
# constrained by a response schema. The returned shape covers every /buscar
# filter that can plausibly be derived from free text — neighborhood, type,
# tags, and price (all fed straight into Merchant.search, see
# app/models/merchant.rb) plus "open now" and "has a loyalty reward", which
# have no Merchant.search-side filtering yet (see the doc comments on
# `open`/`reward` below) and instead flow straight through to /buscar's own
# client-side `open`/`reward` params (see web/lib/search/resolve-ai-search.ts):
#
#   { "neighborhood" => String|nil, "type" => String|nil,
#     "tags" => Array<String>, "price_per_person" => Numeric|nil,
#     "open" => true|false|nil, "reward" => true|false|nil }
#
# Deliberately NOT covered: `dist` (needs the visitor's live geolocation,
# not derivable from text — unlike neighborhood/type/price), `sort`, and
# `mode` (display/UX choices, not filter constraints).
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

  # A method (not a frozen constant computed once at class-load) so the
  # `tags` enum below always reflects the live `tags` table — this table is
  # tiny (a handful of rows, see db/seeds.rb's TAG_NAMES), so a plain query
  # per search request is cheap insurance against the enum silently going
  # stale after a tag is added/removed, the same failure mode that produced
  # the orphan-tag drift this schema is meant to prevent from recurring.
  def self.response_schema
    {
      type: "OBJECT",
      properties: {
        neighborhood: { type: "STRING", nullable: true },
        type: { type: "STRING", nullable: true, enum: Merchant.types.keys },
        tags: { type: "ARRAY", items: { type: "STRING", enum: available_tag_names } },
        price_per_person: { type: "NUMBER", nullable: true },
        # "Abierto ahora" — /buscar's `open=now` param. No Merchant.search-side
        # filter exists for this yet (it's computed client-side from real
        # business hours, see app/buscar/page.tsx's getOpenNowMerchantIds), so
        # this value isn't consumed by Merchant.search either — it's returned
        # in `filters` purely for the client to forward onto that existing
        # client-side "open now" filter (see resolve-ai-search.ts).
        open: { type: "BOOLEAN", nullable: true },
        # "Premio por visitas" — /buscar's `reward=1` param. Same situation as
        # `open`: no backend column/filter exists yet (rewardTeaser is a
        # client-only derived field, see app/buscar/page.tsx's own comment on
        # it), so this also just flows through to the client's existing
        # client-side reward filter.
        reward: { type: "BOOLEAN", nullable: true }
      },
      required: %w[neighborhood type tags price_per_person open reward]
    }
  end

  def self.available_tag_names
    Tag.order(:name).pluck(:name)
  end

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
      restrictions, or other descriptive attributes mentioned in the query,
      restricted to the allowed enum values. Use an empty array if none
      apply.
    - "price_per_person": a numeric price-per-person estimate if the user
      gives one or implies a budget level (e.g. "barato" implies a low
      number), or null if price is not mentioned or explicitly irrelevant
      (e.g. "sin importar el precio").
    - "open": true if the user asks for a place that's open right now (e.g.
      "abierto ahora", "que esté abierto"), false if they explicitly ask for
      the opposite, or null if availability isn't mentioned.
    - "reward": true if the user asks for a place with a loyalty
      reward/perk for visiting (e.g. "que tenga premio por visitas",
      "con recompensas"), false if they explicitly say they don't care
      about that, or null if not mentioned at all.
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
        responseSchema: self.class.response_schema
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
    sanitize_tags!(structured)
    structured
  rescue JSON::ParserError
    raise GeminiError, "Search parsing service returned an unexpected response"
  end

  # The schema's `enum` constraint on `tags` (see .response_schema) is a
  # strong hint, not a hard guarantee — Gemini occasionally still emits a
  # value outside it (e.g. an English synonym like "spicy" instead of
  # "picante"). Silently DROPPING those instead of failing the whole search
  # keeps the orphan-tag guarantee (a client's `filters.tags` never contains
  # anything outside the real vocabulary) without turning an imperfect but
  # recoverable LLM response into a hard 502 for the visitor.
  def sanitize_tags!(structured)
    allowed = self.class.available_tag_names.map(&:downcase)
    structured["tags"] = Array(structured["tags"]).select { |tag| allowed.include?(tag.to_s.downcase) }
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
      valid_optional_number?(structured["price_per_person"]) &&
      valid_optional_boolean?(structured["open"]) &&
      valid_optional_boolean?(structured["reward"])
  end

  def valid_optional_string?(value)
    value.nil? || value.is_a?(String)
  end

  def valid_type?(value)
    value.nil? || (value.is_a?(String) && Merchant.types.key?(value))
  end

  # Shape-only check (array of strings) — membership in the real tag
  # vocabulary is enforced separately by #sanitize_tags!, which drops rather
  # than hard-fails on an out-of-vocabulary value (see its own doc comment
  # for why: the schema's `enum` constraint is a strong hint to Gemini, not a
  # guarantee).
  def valid_tags?(value)
    value.is_a?(Array) && value.all? { |tag| tag.is_a?(String) }
  end

  def valid_optional_number?(value)
    value.nil? || value.is_a?(Numeric)
  end

  def valid_optional_boolean?(value)
    value.nil? || value.is_a?(TrueClass) || value.is_a?(FalseClass)
  end
end
