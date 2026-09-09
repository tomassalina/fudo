# See merchant_blueprint.rb for why extra fields live inside named views
# instead of the class body.
class GiftBlueprint < Blueprinter::Base
  identifier :id

  view :list do
    fields :sender_consumer_id, :recipient_consumer_id, :type, :amount, :status, :expires_at
  end

  view :extended do
    include_view :list

    fields :recipient_phone, :message, :status_updated_at, :created_at, :updated_at
  end
end
