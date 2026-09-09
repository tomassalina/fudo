# See merchant_blueprint.rb for why extra fields live inside named views
# instead of the class body.
class LoyaltyRuleBlueprint < Blueprinter::Base
  identifier :id

  view :list do
    fields :merchant_id, :visits_required, :reward_type, :reward_description, :is_permanent
  end

  view :extended do
    include_view :list

    fields :created_at, :updated_at
  end
end
