# Resolves the authenticated Consumer from a `Authorization: Bearer <jwt>`
# request header. Replaces the old Trackable/X-Actor-Id placeholder now
# that real token-based authentication exists.
module Authenticatable
  extend ActiveSupport::Concern

  UUID_FORMAT = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

  # The consumer identified by the request's bearer token, or nil if there
  # is none, it's malformed/expired, or it no longer identifies an existing
  # consumer.
  def current_consumer
    return @current_consumer if defined?(@current_consumer)

    @current_consumer = consumer_from_token
  end

  # Call as a before_action on any action that requires authentication.
  # Renders 401 and halts the filter chain when there is no valid,
  # non-expired token identifying an existing consumer.
  def authenticate_consumer!
    return if current_consumer

    render json: { error: "Not authenticated" }, status: :unauthorized
  end

  private

  def consumer_from_token
    payload = JsonWebToken.decode(bearer_token)
    return nil unless payload && payload[:sub]

    # A validly-signed token can still carry a malformed `sub` (forged by
    # hand, or from a future/incompatible token format). Without this
    # guard, a non-UUID value reaches Postgres's uuid column and raises
    # ActiveRecord::StatementInvalid, which the base controller's generic
    # rescue_from turns into a 400 — but an authentication failure should
    # always be 401, never 400.
    sub = payload[:sub].to_s
    return nil unless sub.match?(UUID_FORMAT)

    Consumer.find_by(id: sub)
  end

  def bearer_token
    header = request.headers["Authorization"]
    return nil unless header&.start_with?("Bearer ")

    header.delete_prefix("Bearer ").strip
  end
end
