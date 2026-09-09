# Encodes/decodes JSON Web Tokens used to authenticate consumers.
#
# Secret resolution prefers a dedicated JWT_SECRET so token validity is
# independent from Rails' secret_key_base (rotating secret_key_base for
# unrelated reasons would otherwise silently invalidate every issued
# token). The fallback to secret_key_base exists only so development/test
# environments work without extra setup — production should always set
# JWT_SECRET explicitly.
module JsonWebToken
  ALGORITHM = "HS256"
  EXPIRATION = 30.days

  module_function

  def secret
    ENV.fetch("JWT_SECRET") { Rails.application.secret_key_base }
  end

  # payload: a Hash merged with an `exp` claim. Caller is expected to pass
  # at least `sub:` (the consumer id).
  def encode(payload, exp = EXPIRATION.from_now)
    payload = payload.merge(exp: exp.to_i)
    JWT.encode(payload, secret, ALGORITHM)
  end

  # Returns the decoded payload (HashWithIndifferentAccess) or nil if the
  # token is missing, malformed, expired, or has an invalid signature.
  def decode(token)
    return nil if token.blank?

    decoded = JWT.decode(token, secret, true, algorithm: ALGORITHM).first
    ActiveSupport::HashWithIndifferentAccess.new(decoded)
  rescue JWT::DecodeError
    nil
  end
end
