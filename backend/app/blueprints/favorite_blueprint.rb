class FavoriteBlueprint < Blueprinter::Base
  identifier :id

  fields :consumer_id, :merchant_id, :created_at

  view :list do
  end
end
