# Resolves the "actor" performing a write request (used to populate the
# created_by/updated_by/deleted_by audit columns) from the `X-Actor-Id`
# request header.
#
# PLACEHOLDER: there is no authentication/session system yet. Once real auth
# exists, this concern should be replaced by reading the actor from the
# authenticated session/token instead of a client-supplied header.
module Trackable
  extend ActiveSupport::Concern

  UUID_FORMAT = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

  # Returns the actor id from the X-Actor-Id header if present and a
  # well-formed UUID, otherwise nil.
  def current_actor_id
    return @current_actor_id if defined?(@current_actor_id)

    header = request.headers["X-Actor-Id"]
    @current_actor_id = header if header.present? && header.match?(UUID_FORMAT)
  end

  # Call at the top of any write action that needs to stamp an audit column.
  # Renders a 400 and returns nil when the header is missing/invalid, so
  # callers can guard with `return unless (actor_id = require_actor_id!)`.
  def require_actor_id!
    return current_actor_id if current_actor_id

    render json: { error: "Missing or invalid X-Actor-Id header" }, status: :bad_request
    nil
  end
end
