# Fail fast at boot in production if JWT_SECRET isn't set, rather than
# silently falling back to secret_key_base (see app/lib/json_web_token.rb)
# — that fallback exists only as a dev/test convenience. In production,
# JWT auth should have its own dedicated secret so rotating
# secret_key_base for unrelated reasons (session/cookie signing) doesn't
# also silently invalidate every issued consumer token, and vice versa.
#
# See ENV_SETUP.md for how to generate one (`bin/rails secret`).
if Rails.env.production? && ENV["JWT_SECRET"].blank?
  raise "JWT_SECRET must be set in production — see ENV_SETUP.md."
end
