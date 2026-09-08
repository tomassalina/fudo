# Fields declared directly on the class body (outside any `view do...end`
# block) belong to Blueprinter's implicit `:default` view — and `:default`
# fields are merged into EVERY named view, `:list` included. So this class
# body only declares `identifier :id` (always rendered in every view); the
# small index payload lives in `:list`, and the full detail payload lives in
# `:extended` (which explicitly pulls `:list`'s fields in via
# `include_view`, since sibling views do NOT inherit from each other).
class MerchantBlueprint < Blueprinter::Base
  identifier :id

  # Small field set for index — no nested associations.
  view :list do
    fields :name, :type, :neighborhood, :city, :price_per_person_min,
           :price_per_person_max, :cover_image_url, :latitude, :longitude
  end

  # Full detail for show/create/update — includes tags (as plain name
  # strings) and business hours.
  view :extended do
    include_view :list

    fields :address, :country, :state, :zip_code, :whatsapp_number,
           :delivery_url, :created_at, :updated_at

    field :tags do |merchant, _options|
      merchant.tags.pluck(:name)
    end

    association :business_hours, blueprint: BusinessHourBlueprint
  end
end
