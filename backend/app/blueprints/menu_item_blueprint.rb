# See merchant_blueprint.rb for why extra fields live inside named views
# instead of the class body.
class MenuItemBlueprint < Blueprinter::Base
  identifier :id

  view :list do
    fields :merchant_id, :name, :price, :currency, :section, :image_url, :active
  end

  view :extended do
    include_view :list

    fields :description, :created_at, :updated_at

    field :tags do |menu_item, _options|
      menu_item.tags.pluck(:name)
    end
  end
end
