# See merchant_blueprint.rb for why extra fields live inside named views
# instead of the class body.
class SearchHistoryBlueprint < Blueprinter::Base
  identifier :id

  view :list do
    fields :consumer_id, :query_text, :created_at
  end

  view :extended do
    include_view :list

    fields :structured_output, :updated_at
  end
end
