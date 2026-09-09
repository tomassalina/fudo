class VisitSummaryBlueprint < Blueprinter::Base
  identifier :id

  fields :consumer_id, :merchant_id, :count, :current_tier, :last_visit_at

  view :list do
  end
end
