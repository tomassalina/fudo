class ConsumerSettingBlueprint < Blueprinter::Base
  identifier :id

  fields :consumer_id, :theme, :notifications_enabled, :updated_at

  view :list do
  end
end
