class TagBlueprint < Blueprinter::Base
  identifier :id

  fields :name

  view :list do
  end

  view :extended do
    fields :created_at, :updated_at
  end
end
