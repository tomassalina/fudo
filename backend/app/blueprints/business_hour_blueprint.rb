class BusinessHourBlueprint < Blueprinter::Base
  identifier :id

  fields :merchant_id, :day_of_week, :opens_at, :closes_at, :closed

  view :list do
    # Business hours have no heavy nested associations of their own, so the
    # list and default views carry the same fields.
  end
end
