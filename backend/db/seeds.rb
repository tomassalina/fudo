# Fudo Consumers — Phase 1 demo data seed.
#
# Generates fully fictional, but realistic, demo data for the Palermo
# (Ciudad Autónoma de Buenos Aires, Argentina) neighborhood: merchants, menu
# items, tags, business hours (including double-shift days), loyalty rules,
# one demo consumer with encrypted DNI, visit history and a couple of
# favorites/gifts.
#
# Idempotent-safe: deletes previously-seeded rows (children before parents,
# to respect the FK constraints) before recreating them, so `rails db:seed`
# can be re-run without crashing on unique constraint violations.
#
# --- Lockbox / blind_index master keys (read this if you're setting up env vars) ---
# `Consumer#dni` is encrypted at rest via Lockbox (`dni_encrypted`) with a
# blind index (`dni_bidx`) for uniqueness/lookups (see app/models/consumer.rb
# and config/initializers/lockbox.rb). Neither gem had a master key configured
# yet, so for this seed to actually exercise real encryption (instead of
# hardcoding fake ciphertext), two DEV-ONLY keys were generated with
# `SecureRandom.hex(32)` and written to `backend/.env` as `LOCKBOX_MASTER_KEY`
# and `BLIND_INDEX_MASTER_KEY` (confirmed covered by backend/.gitignore's
# `/.env*` pattern — never commit that file).
#
# IMPORTANT for whoever owns the project's real secrets/env var setup: these
# are throwaway local dev keys, not a production secrets story. Replace them
# (Rails credentials, Docker secrets, a vault, etc.) and reconcile
# backend/.env with wherever the rest of the app's env vars end up living
# before relying on this beyond local dev/demo.

puts "Seeding Fudo Consumers demo data (Palermo, CABA, Argentina)..."

SYSTEM_ACTOR_ID = SecureRandom.uuid
TODAY = Time.zone.local(2026, 9, 8)

# ----------------------------------------------------------------------------
# Cleanup (children before parents, FKs are RESTRICT by default)
# ----------------------------------------------------------------------------
puts "Clearing previously seeded data..."
[ Gift, Favorite, Visit, VisitSummary, LoyaltyRule, BusinessHour,
 MenuItemsTag, MerchantsTag, MenuItem, ConsumerSetting, SearchHistory,
 Consumer, Merchant, Tag ].each(&:delete_all)

# ----------------------------------------------------------------------------
# Tags
# ----------------------------------------------------------------------------
puts "Creating tags..."
TAG_NAMES = %w[
  sin_tacc vegano vegetariano picante economico
].freeze

tags = TAG_NAMES.index_with do |name|
  Tag.create!(name: name, created_by: SYSTEM_ACTOR_ID)
end

# ----------------------------------------------------------------------------
# Real Unsplash photos (merchant covers & menu item photos)
# ----------------------------------------------------------------------------
# Source: docs/design-reference/Fudo Customers.dc.html (the approved design
# reference for the mobile app). Every Unsplash photo ID below was copied
# verbatim from that file — none were invented. They appear there as:
#   - <meta name="ext-resource-dependency" ... images.unsplash.com/photo-...>
#     preload tags (lines ~40-135),
#   - the `M(...)` mock-merchant array, one photo ID per merchant, grouped
#     below by `type` (lines ~1073-1102),
#   - the `IMG` / `IMG_RULES` / `imgFor(name, i)` dish-photo lookup used by
#     the design to pick a food photo from a dish's name (lines ~1152-1193).
#
# URL convention:
#   https://images.unsplash.com/photo-<ID>?w=<W>&q=80&auto=format&fit=crop
# using w=1200 for merchant cover images (wide hero banners) and w=800 for
# menu item photos (grid/list thumbnails).
#
# Matching criterion:
# - Merchant covers: grouped by merchant `type` exactly as the design
#   reference paired them (MERCHANT_COVER_PHOTO_IDS_BY_TYPE), then cycled by
#   occurrence index per type — reusing IDs when a type has more seeded
#   merchants than distinct design photos for that type (e.g. pizzeria has
#   only 1 design photo for 3 seeded pizzerias).
# - Menu items: ported verbatim from the design's own `IMG_RULES` keyword
#   list (dish name -> category -> photo ID), applied to each seeded dish
#   name; falls back to the design's own "table" (generic plate) photo when
#   no keyword matches.
#
# Unique photo IDs used (29 total, all present in the design reference):
#   1414235077428-338989a2e8c0  1436076863939-06870fe779c2
#   1470337458703-46ad1756a187  1476224203421-9ac39bcb3327
#   1495474472287-4d71bcdd2085  1504674900247-0877df9cc836
#   1512058564366-18510be2db19  1514362545857-3bc16c4c7d1b
#   1514933651103-005eec06c04b  1521017432531-fbd92d768814
#   1529042410759-befb1204b468  1533777324565-a040eb52facd
#   1540189549336-e6e99c3679fe  1546069901-ba9599a7e63c
#   1551024709-8f23befc6f87     1551782450-a2132b4ba21d
#   1554118811-1e0d58224f24     1555939594-58d7cb561ad1
#   1558030006-450675393462     1565299624946-b28f40a0ae38
#   1565958011703-44f9829ba187  1569718212165-3a8278d5f624
#   1572116469696-31de0f17cc34  1579871494447-9811cf80d66c
#   1591814468924-caf88d1232e1  1600891964092-4316c288032e
#   1601050690597-df0568f70950  1608270586620-248524c67de9
#   1621263764928-df1444c5e859

def unsplash_url(photo_id, width)
  "https://images.unsplash.com/photo-#{photo_id}?w=#{width}&q=80&auto=format&fit=crop"
end

# Grouped by merchant `type`, taken verbatim from the design reference's
# M(...) mock-merchant array (each entry there pairs one merchant of a given
# type with one specific photo ID).
MERCHANT_COVER_PHOTO_IDS_BY_TYPE = {
  "restaurant" => %w[
    1476224203421-9ac39bcb3327 1600891964092-4316c288032e 1579871494447-9811cf80d66c
    1540189549336-e6e99c3679fe 1558030006-450675393462 1414235077428-338989a2e8c0
    1591814468924-caf88d1232e1 1504674900247-0877df9cc836 1529042410759-befb1204b468
    1569718212165-3a8278d5f624 1572116469696-31de0f17cc34
  ],
  "cafe" => %w[
    1554118811-1e0d58224f24 1495474472287-4d71bcdd2085 1521017432531-fbd92d768814
    1533777324565-a040eb52facd 1565958011703-44f9829ba187
  ],
  "bar" => %w[
    1514933651103-005eec06c04b 1470337458703-46ad1756a187 1551024709-8f23befc6f87
    1514362545857-3bc16c4c7d1b
  ],
  "pizzeria" => %w[1565299624946-b28f40a0ae38],
  "dark_kitchen" => %w[
    1512058564366-18510be2db19 1551782450-a2132b4ba21d 1546069901-ba9599a7e63c
  ],
  "brewery" => %w[1608270586620-248524c67de9 1436076863939-06870fe779c2],
  "food_truck" => %w[1555939594-58d7cb561ad1 1601050690597-df0568f70950]
}.freeze

# Dish-name keyword -> photo category, ported verbatim (same order — first
# match wins) from the design reference's IMG_RULES.
DISH_PHOTO_RULES = [
  [ /taco|quesadilla|birria|pastor/i, "taco" ],
  [ /empanada|tamal/i, "empanada" ],
  [ /pizza|fugazzeta|fain|napolitana|muzzarella/i, "pizza" ],
  [ /bife|asado|costillar|vac[ií]o|bondiola|chorizo|molleja|provoleta|ojo de bife|choripán|parrilla|milanesa/i, "grill" ],
  [ /salm[oó]n|ceviche|corvina/i, "steak" ],
  [ /ramen|wok|pad thai|fideos|ravioles|pasta|gyoza/i, "noodle" ],
  [ /sushi|niguiri|roll spicy|combinado|edamame|sake/i, "sushi" ],
  [ /burger|hamburguesa|cheddar|smash/i, "burger" ],
  [ /caf[eé]|espresso|latte|cappuccino|cold brew|submarino|filtrado|flat white|t[eé] verde/i, "coffee" ],
  [ /croissant|medialuna|pan |budín|budin|roll de canela|alfajor|cheesecake|tiramis|flan|postre|dulce de leche|masa madre|pastel/i, "bakery" ],
  [ /ensalada|hummus|falafel|tarta|guacamole|elote|bowl|quinoa|wrap|tostado|palta|burrata/i, "veg" ],
  [ /pinta|cerveza|alitas|stout|ipa/i, "beer" ],
  [ /copa|vino|malbec|blend|c[oó]ctel|negroni|gin|vermú|vermu/i, "drink" ],
  [ /limonada|jugo|agua|jamaica|gaseosa|soda/i, "soft" ],
  [ /papas|totopos|tortilla|rabas|tabla|picada|focaccia|queso/i, "plate" ]
].freeze

# Same photo IDs the design reference's IMG map uses for each dish category
# (the "table" entry is the design's own generic fallback photo).
DISH_PHOTO_IDS = {
  "taco" => "1476224203421-9ac39bcb3327",
  "empanada" => "1601050690597-df0568f70950",
  "pizza" => "1565299624946-b28f40a0ae38",
  "grill" => "1558030006-450675393462",
  "steak" => "1600891964092-4316c288032e",
  "noodle" => "1569718212165-3a8278d5f624",
  "sushi" => "1579871494447-9811cf80d66c",
  "burger" => "1551782450-a2132b4ba21d",
  "coffee" => "1495474472287-4d71bcdd2085",
  "bakery" => "1565958011703-44f9829ba187",
  "veg" => "1540189549336-e6e99c3679fe",
  "beer" => "1608270586620-248524c67de9",
  "drink" => "1551024709-8f23befc6f87",
  "soft" => "1621263764928-df1444c5e859",
  "plate" => "1529042410759-befb1204b468",
  "table" => "1414235077428-338989a2e8c0"
}.freeze

def dish_photo_id(dish_name)
  category = DISH_PHOTO_RULES.find { |(regex, _)| regex.match?(dish_name) }&.last || "table"
  DISH_PHOTO_IDS.fetch(category)
end

# ----------------------------------------------------------------------------
# Merchants
# ----------------------------------------------------------------------------
puts "Creating merchants..."

# name, type, street address, price_per_person_min, price_per_person_max (ARS).
# Price bands are a judgment call for "September 2026" pricing (no real
# published data to anchor to) — scaled up from mid-2024 Palermo price
# levels by an assumed further ~18 months of Argentine inflation.
MERCHANTS_DATA = [
  [ "La Cocina de Mateo", "restaurant", "Gorriti 4820", 22000, 38000 ],
  [ "Almacén Malabia", "restaurant", "Malabia 1621", 24000, 40000 ],
  [ "Che Bo Parrilla", "restaurant", "Nicaragua 5934", 28000, 46000 ],
  [ "Rincón Costa Rica", "restaurant", "Costa Rica 4711", 21000, 35000 ],
  [ "Sótano Armenia", "restaurant", "Armenia 1556", 26000, 42000 ],
  [ "El Fogón de Julián", "restaurant", "Honduras 4890", 25000, 41000 ],
  [ "Vacío y Vino", "restaurant", "Thames 1780", 30000, 48000 ],
  [ "Cocina Serrana", "restaurant", "Cabrera 5322", 23000, 37000 ],
  [ "La Parrilla de Borges", "restaurant", "Jorge Luis Borges 2145", 27000, 44000 ],
  [ "Bodegón Guatemala", "restaurant", "Guatemala 4675", 20000, 34000 ],
  [ "Café Niceto", "cafe", "Niceto Vega 5480", 9000, 15000 ],
  [ "Tostado & Café Dorrego", "cafe", "Plaza Dorrego 234", 8500, 14000 ],
  [ "Medialuna Club", "cafe", "El Salvador 4711", 9500, 16000 ],
  [ "Café Dorado Fitz Roy", "cafe", "Fitz Roy 1890", 10000, 17000 ],
  [ "La Tostadora Migueletes", "cafe", "Migueletes 1345", 9000, 15500 ],
  [ "Cortado Arévalo", "cafe", "Arévalo 2015", 8800, 14500 ],
  [ "Bar Soler", "bar", "Soler 5230", 15000, 26000 ],
  [ "El Rincón de Gorriti", "bar", "Gorriti 5610", 14000, 24000 ],
  [ "Cervecería Cabrera", "bar", "Cabrera 4980", 16000, 27000 ],
  [ "Bar Santa Fe Alto", "bar", "Santa Fe 4210", 15500, 25000 ],
  [ "Vermutería Guatemala", "bar", "Guatemala 5122", 17000, 28000 ],
  [ "Bodega Cerviño", "bar", "Cerviño 3980", 16500, 26500 ],
  [ "Pizzería Malabia Vieja", "pizzeria", "Malabia 2001", 17000, 29000 ],
  [ "La Fugazzeta de Thames", "pizzeria", "Thames 1420", 16000, 27000 ],
  [ "Horno a Leña Honduras", "pizzeria", "Honduras 3785", 18000, 30000 ],
  [ "Poke & Go Palermo", "dark_kitchen", "Costa Rica 5680", 11000, 19000 ],
  [ "Cocina Oculta Soho", "dark_kitchen", "Gurruchaga 1988", 12000, 20000 ],
  [ "Fábrica Cervecera Nicaragua", "brewery", "Nicaragua 4550", 16000, 28000 ],
  [ "Cervecería Palermo Hollywood", "brewery", "Humboldt 1690", 15500, 27500 ],
  [ "Food Truck El Zaguán", "food_truck", "Plazoleta Serrano s/n", 7000, 12500 ]
].freeze

# Deterministic pseudo-random coordinates within Palermo's real bounding box
# (~lat -34.595..-34.565, lng -58.452..-58.398), so points are real, distinct
# and spread across the neighborhood rather than stacked on one point.
geo_rng = Random.new(20_260_908)

# Cycles each merchant `type`'s design-reference photo pool independently, so
# merchants of the same type don't all collide on occurrence 0.
merchant_type_occurrence = Hash.new(0)

merchants = MERCHANTS_DATA.each_with_index.map do |(name, type, address, price_min, price_max), index|
  lat = (-34.595 + geo_rng.rand * 0.030).round(6)
  lng = (-58.452 + geo_rng.rand * 0.054).round(6)

  cover_photo_pool = MERCHANT_COVER_PHOTO_IDS_BY_TYPE.fetch(type)
  cover_photo_id = cover_photo_pool[merchant_type_occurrence[type] % cover_photo_pool.size]
  merchant_type_occurrence[type] += 1

  Merchant.create!(
    name: name,
    type: type,
    address: address,
    country: "Argentina",
    state: "Ciudad Autónoma de Buenos Aires",
    city: "Ciudad Autónoma de Buenos Aires",
    neighborhood: "Palermo",
    zip_code: "C1414",
    latitude: lat,
    longitude: lng,
    cover_image_url: unsplash_url(cover_photo_id, 1200),
    whatsapp_number: "+5491150001#{format('%03d', index)}",
    price_per_person_min: price_min,
    price_per_person_max: price_max,
    created_by: SYSTEM_ACTOR_ID
  )
end

# ----------------------------------------------------------------------------
# Merchant tags
# ----------------------------------------------------------------------------
puts "Tagging merchants..."

# restaurant/cafe/bar/pizzeria/brewery have no type-level tag of their own
# (their earlier con_terraza/wifi_gratis/pet_friendly/con_delivery entries
# were removed — those 5 tags are amenity tags with no /buscar filter slot,
# out of scope; see EXTRA_DIETARY_TAGS_MERCHANT_NAMES below for the real,
# filterable dietary tags those merchants still carry).
MERCHANT_TAGS_BY_TYPE = {
  # dark_kitchen's own dish pool already leans spicy (e.g. "Ramen picante
  # para llevar", "Tacos de carnitas (x3)") — "picante" here is a coherent
  # merchant-level tag, not a random pick. Covers the /buscar "Apto para"
  # row's hardcoded picante option (filter-rows.ts DIET_TAG_KEYS), which
  # otherwise had zero matching tags in the DB (no seed merchant/menu_item
  # carried "picante" before this).
  "dark_kitchen" => %w[vegano picante],
  # food_truck is the seed's cheapest price band by a wide margin (Food
  # Truck El Zaguán: $7.000-$12.500 vs. the next-cheapest cafe at
  # $8.500-$14.000+) — "economico" here is the natural real merchant for
  # that tag, covering the /buscar AI-chips "Económico" option, which
  # otherwise had zero matching tags in the DB.
  "food_truck" => %w[economico]
}.freeze

# A handful of merchants (regardless of type) additionally cater to
# dietary-restriction diners, to exercise sin_tacc / vegetariano / vegano —
# "vegetariano" here is what covers the /buscar "Apto para" row's
# vegetariano option (filter-rows.ts DIET_TAG_KEYS), same rationale as
# picante/economico above: without at least one real merchant carrying it,
# that filter option would be a guaranteed 0-result dead end.
EXTRA_DIETARY_TAGS_MERCHANT_NAMES = {
  "La Cocina de Mateo" => %w[sin_tacc],
  "Cocina Serrana" => %w[vegetariano],
  "Café Niceto" => %w[sin_tacc],
  "Poke & Go Palermo" => %w[vegetariano],
  "Cocina Oculta Soho" => %w[sin_tacc vegano],
  "Vermutería Guatemala" => %w[vegetariano]
}.freeze

merchants.each do |merchant|
  tag_names = MERCHANT_TAGS_BY_TYPE.fetch(merchant.type, []) +
              EXTRA_DIETARY_TAGS_MERCHANT_NAMES.fetch(merchant.name, [])

  tag_names.uniq.each do |tag_name|
    MerchantsTag.create!(merchant: merchant, tag: tags.fetch(tag_name))
  end
end

# ----------------------------------------------------------------------------
# Menu items (150 = 30 merchants x 5 items each)
# ----------------------------------------------------------------------------
puts "Creating menu items..."

DISH_POOLS = {
  "restaurant" => [
    "Milanesa napolitana con papas fritas", "Bife de chorizo", "Empanadas de carne (docena)",
    "Provoleta", "Ensalada César", "Papas fritas con cheddar y panceta",
    "Tarta de acelga y queso", "Locro criollo", "Matambre a la pizza", "Vacío al asador"
  ],
  "cafe" => [
    "Medialunas de manteca (x3)", "Tostado de jamón y queso", "Café con leche",
    "Licuado de banana y frutilla", "Submarino", "Budín de limón",
    "Avocado toast", "Chipá", "Cappuccino", "Jugo de naranja exprimido"
  ],
  "bar" => [
    "Picada para dos", "Cerveza artesanal IPA (pinta)", "Papas bravas",
    "Nachos con guacamole", "Rabas fritas", "Hamburguesa doble cheddar",
    "Sandwich de bondiola", "Tabla de fiambres y quesos", "Copa de vino Malbec", "Alitas BBQ"
  ],
  "pizzeria" => [
    "Pizza muzzarella", "Pizza fugazzeta rellena", "Pizza especial jamón y morrones",
    "Calzone de jamón y queso", "Empanada árabe", "Faina",
    "Pizza cuatro quesos", "Pizza napolitana", "Palmeritas de anchoa", "Fugazza con queso"
  ],
  "dark_kitchen" => [
    "Bowl poke de salmón", "Wrap de pollo grillado", "Sushi roll California",
    "Ramen picante para llevar", "Ensalada de quinoa y vegetales", "Curry de garbanzos",
    "Hamburguesa vegana", "Tacos de carnitas (x3)", "Poke bowl vegetariano", "Noodles salteados con vegetales"
  ],
  "brewery" => [
    "Cerveza IPA artesanal (pinta)", "Cerveza stout (pinta)", "Tabla de picada cervecera",
    "Choripán artesanal", "Bondiola a la cerveza negra", "Pretzel con mostaza",
    "Hamburguesa smash", "Papas rústicas", "Nachos con cheddar", "Alitas picantes"
  ],
  "food_truck" => [
    "Choripán clásico", "Bondiola al pan con chimichurri", "Papas fritas artesanales",
    "Hamburguesa smash simple", "Panchito especial", "Limonada casera",
    "Cerveza en lata", "Sanguche de milanesa", "Vaso de papas con cheddar", "Brownie con helado"
  ]
}.freeze

# Dish names that get an automatic dietary tag, matched by keyword.
DISH_TAG_RULES = {
  "vegano" => [ "vegana", "quinoa", "garbanzos", "vegetales" ],
  "vegetariano" => [ "vegetariano", "acelga", "quinoa" ],
  "sin_tacc" => [ "provoleta", "rabas", "milanesa" ],
  # Matches dishes whose own name says "picante" ("Ramen picante para
  # llevar", "Alitas picantes") — real dishes, not a random pick, and the
  # menu_item-level complement to the dark_kitchen merchant-level tag above.
  "picante" => [ "picante" ]
}.freeze

def tags_for_dish(name, tags)
  DISH_TAG_RULES.filter_map do |tag_name, keywords|
    tags[tag_name] if keywords.any? { |kw| name.downcase.include?(kw) }
  end
end

menu_items = []

merchants.each_with_index do |merchant, merchant_index|
  pool = DISH_POOLS.fetch(merchant.type)
  # Rotate the 5-item slice through the 10-item pool so merchants sharing a
  # type don't all get an identical menu.
  offset = (merchant_index * 3) % pool.size
  dish_names = pool.rotate(offset).first(5)

  dish_names.each_with_index do |dish_name, item_index|
    price_span = merchant.price_per_person_max - merchant.price_per_person_min
    price = (merchant.price_per_person_min + price_span * ((item_index + 1) / 6.0)).round(-2)

    item = MenuItem.create!(
      merchant: merchant,
      name: dish_name,
      description: "#{dish_name} — especialidad de #{merchant.name}.",
      price: price,
      currency: "ars",
      section: item_index < 2 ? "Entradas" : "Principales",
      image_url: unsplash_url(dish_photo_id(dish_name), 800),
      active: true,
      created_by: SYSTEM_ACTOR_ID
    )
    menu_items << item

    tags_for_dish(dish_name, tags).each do |tag|
      MenuItemsTag.find_or_create_by!(menu_item: item, tag: tag)
    end
  end
end

# ----------------------------------------------------------------------------
# Business hours (210 rows total)
#   - 6 merchants: standard 7-day week + a double shift on one day (8 rows each = 48)
#   - 6 merchants: closed one full day, no row for it (6 rows each = 36)
#   - 18 merchants: standard 7-day week, one day explicitly marked closed (7 rows each = 126)
#   48 + 36 + 126 = 210
# ----------------------------------------------------------------------------
puts "Creating business hours..."

DAYS = BusinessHour.day_of_weeks.keys

HOURS_BY_TYPE = {
  "restaurant" => %w[12:00 00:00],
  "cafe" => %w[08:00 20:00],
  "bar" => %w[18:00 02:00],
  "pizzeria" => %w[19:00 01:00],
  "dark_kitchen" => %w[11:00 23:00],
  "brewery" => %w[17:00 01:00],
  "food_truck" => %w[11:00 22:00]
}.freeze

double_shift_merchants = merchants.first(6)
day_off_merchants = merchants[6...12]
standard_merchants = merchants[12...30]

# One doubled day per double-shift merchant; the first one is Monday on
# purpose, to reproduce the exact "Monday lunch + Monday dinner" example.
doubled_days = %w[monday tuesday wednesday thursday friday saturday]

double_shift_merchants.each_with_index do |merchant, index|
  doubled_day = doubled_days[index]

  DAYS.each do |day|
    if day == doubled_day
      BusinessHour.create!(merchant: merchant, day_of_week: day, opens_at: "12:00", closes_at: "15:30", closed: false)
      BusinessHour.create!(merchant: merchant, day_of_week: day, opens_at: "20:00", closes_at: "00:30", closed: false)
    else
      open_time, close_time = HOURS_BY_TYPE.fetch(merchant.type)
      BusinessHour.create!(merchant: merchant, day_of_week: day, opens_at: open_time, closes_at: close_time, closed: false)
    end
  end
end

day_off_merchants.each do |merchant|
  open_time, close_time = HOURS_BY_TYPE.fetch(merchant.type)
  (DAYS - [ "monday" ]).each do |day|
    BusinessHour.create!(merchant: merchant, day_of_week: day, opens_at: open_time, closes_at: close_time, closed: false)
  end
end

standard_merchants.each do |merchant|
  open_time, close_time = HOURS_BY_TYPE.fetch(merchant.type)
  DAYS.each do |day|
    if day == "sunday"
      BusinessHour.create!(merchant: merchant, day_of_week: day, opens_at: nil, closes_at: nil, closed: true)
    else
      BusinessHour.create!(merchant: merchant, day_of_week: day, opens_at: open_time, closes_at: close_time, closed: false)
    end
  end
end

# ----------------------------------------------------------------------------
# Loyalty rules (150 = 30 merchants x 5 tiers each)
# ----------------------------------------------------------------------------
puts "Creating loyalty rules..."

LOYALTY_TIERS = [
  { visits_required: 2, reward_type: "discount_percent", reward_description: "10% de descuento en la cuenta total" },
  { visits_required: 4, reward_type: "free_item", reward_description: "Postre o café de cortesía" },
  { visits_required: 6, reward_type: "cashback", reward_description: "15% de cashback en tu próxima visita" },
  { visits_required: 8, reward_type: "discount_percent", reward_description: "20% de descuento en la cuenta total" },
  { visits_required: 10, reward_type: "other", reward_description: "Cliente frecuente: beneficio permanente en cada visita" }
].freeze

merchants.each do |merchant|
  LOYALTY_TIERS.each do |tier|
    LoyaltyRule.create!(
      merchant: merchant,
      visits_required: tier[:visits_required],
      reward_type: tier[:reward_type],
      reward_description: tier[:reward_description],
      is_permanent: tier[:visits_required] == 10,
      created_by: SYSTEM_ACTOR_ID
    )
  end
end

# ----------------------------------------------------------------------------
# Demo consumer
# ----------------------------------------------------------------------------
puts "Creating demo consumer..."

# first_name/last_name may be real; email, DNI, and password are
# fictional/demo placeholders — this file is committed to git in
# plaintext, unlike backend/.env, so no real credentials go here.
consumer = Consumer.create!(
  first_name: "Tomas",
  last_name: "Salina",
  email: "info@tomassalina.com",
  password_hash: BCrypt::Password.create("Demo1234"),
  dni: "12345678",
  phone: "+5491122334455",
  created_by: SYSTEM_ACTOR_ID
)

ConsumerSetting.create!(consumer: consumer, theme: "dark", notifications_enabled: true, updated_by: SYSTEM_ACTOR_ID)

# ----------------------------------------------------------------------------
# Visit summaries (27) and visits (116) for the demo consumer
# ----------------------------------------------------------------------------
puts "Creating visit summaries and visits..."

visited_merchants = merchants.first(27)

# 8 merchants get 5 visits, the remaining 19 get 4 visits -> 8*5 + 19*4 = 116.
visit_counts = Array.new(8, 5) + Array.new(19, 4)

visited_merchants.each_with_index do |merchant, index|
  visit_count = visit_counts[index]
  merchant_loyalty_rules = LoyaltyRule.where(merchant: merchant).order(:visits_required)

  visited_dates = visit_count.times.map { |n| TODAY - (visit_count - n) * 12.days - index.days }

  visits = visited_dates.each_with_index.map do |visited_at, visit_number|
    visits_so_far = visit_number + 1
    reached_rule = merchant_loyalty_rules.select { |rule| rule.visits_required <= visits_so_far }.last
    reward_applied = reached_rule.present? && visits_so_far == reached_rule.visits_required

    Visit.create!(
      consumer: consumer,
      merchant: merchant,
      amount: (merchant.price_per_person_min + rand(0..(merchant.price_per_person_max - merchant.price_per_person_min))).round(-2),
      reward_applied: reward_applied,
      reward_description_snapshot: reward_applied ? reached_rule.reward_description : nil,
      visited_at: visited_at,
      created_by: SYSTEM_ACTOR_ID
    )
  end

  highest_reached = merchant_loyalty_rules.select { |rule| rule.visits_required <= visit_count }.last
  current_tier = highest_reached ? "Nivel #{highest_reached.visits_required} visitas" : "Nuevo"

  VisitSummary.create!(
    consumer: consumer,
    merchant: merchant,
    count: visit_count,
    current_tier: current_tier,
    last_visit_at: visits.map(&:visited_at).max
  )
end

# ----------------------------------------------------------------------------
# Favorites (3)
# ----------------------------------------------------------------------------
puts "Creating favorites..."

visited_merchants.first(3).each do |merchant|
  Favorite.create!(consumer: consumer, merchant: merchant, created_by: SYSTEM_ACTOR_ID)
end

# ----------------------------------------------------------------------------
# Gifts (3)
# ----------------------------------------------------------------------------
puts "Creating gifts..."

GIFTS_DATA = [
  { type: "classic", amount: 5000, status: "pending", message: "¡Feliz cumple! Disfrutá una cena en Palermo." },
  { type: "gold", amount: 12000, status: "redeemed", message: "Gracias por todo, un gustito de mi parte." },
  { type: "black", amount: 20000, status: "pending", message: "Para celebrar tu ascenso." }
].freeze

GIFTS_DATA.each_with_index do |gift_data, index|
  Gift.create!(
    sender: consumer,
    recipient: nil,
    type: gift_data[:type],
    amount: gift_data[:amount],
    recipient_phone: "+549115500#{format('%04d', index + 1)}",
    message: gift_data[:message],
    expires_at: TODAY + 3.months,
    status: gift_data[:status],
    status_updated_at: gift_data[:status] == "redeemed" ? TODAY - 2.days : nil,
    created_by: SYSTEM_ACTOR_ID
  )
end

# ----------------------------------------------------------------------------
# Summary
# ----------------------------------------------------------------------------
puts "\nSeed summary:"
puts "  Tags: #{Tag.count}"
puts "  Merchants: #{Merchant.count}"
puts "  MenuItems: #{MenuItem.count}"
puts "  MerchantsTags: #{MerchantsTag.count}"
puts "  MenuItemsTags: #{MenuItemsTag.count}"
puts "  BusinessHours: #{BusinessHour.count}"
puts "  LoyaltyRules: #{LoyaltyRule.count}"
puts "  Consumers: #{Consumer.count}"
puts "  ConsumerSettings: #{ConsumerSetting.count}"
puts "  VisitSummaries: #{VisitSummary.count}"
puts "  Visits: #{Visit.count}"
puts "  Favorites: #{Favorite.count}"
puts "  Gifts: #{Gift.count}"
puts "Done."
