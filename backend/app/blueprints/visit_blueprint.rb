# See merchant_blueprint.rb for why extra fields live inside named views
# instead of the class body.
class VisitBlueprint < Blueprinter::Base
  identifier :id

  view :list do
    fields :consumer_id, :merchant_id, :amount, :visited_at, :reward_applied
  end

  view :extended do
    include_view :list

    fields :reward_description_snapshot, :created_at, :updated_at
  end
end
