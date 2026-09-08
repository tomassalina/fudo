# Public-facing consumer representation for auth endpoints (registration,
# session). Deliberately excludes password_hash, dni (encrypted PII), and
# audit columns.
class ConsumerBlueprint < Blueprinter::Base
  identifier :id

  fields :email, :first_name, :last_name, :phone
end
