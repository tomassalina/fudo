require "rails_helper"

# Regression spec for a bug reported live by the product owner with real
# evidence: `/buscar?tags=sin_tacc&hood=palermo&...` (lowercase) returned
# ZERO results while `?hood=Palermo` (matching the DB's exact stored
# casing) worked. Root cause: Merchant.search's neighborhood filter used an
# exact `where(neighborhood: ...)` match, which is case-sensitive at the SQL
# level. Neighborhood text can arrive in arbitrary casing from more than one
# untrusted source — Gemini's free-text extraction (SearchQueryParser),
# a manually-typed URL param, or future seed data using a different casing
# convention — so the fix must live in Merchant.search itself, not in any
# one caller.
RSpec.describe Merchant, ".search" do
  let(:actor_id) { SecureRandom.uuid }

  def create_merchant(neighborhood:)
    Merchant.create!(
      name: "Merchant #{SecureRandom.hex(4)}", type: "restaurant", address: "Av. Test 123",
      country: "Argentina", state: "Buenos Aires", city: "CABA", neighborhood: neighborhood,
      latitude: -34.6, longitude: -58.4, created_by: actor_id
    )
  end

  describe "neighborhood matching" do
    it "matches regardless of casing, returning the same merchants for lowercase and stored casing" do
      palermo = create_merchant(neighborhood: "Palermo")
      belgrano = create_merchant(neighborhood: "Belgrano")

      # Scoped to these two freshly-created rows on purpose — db/seeds.rb
      # also seeds a "Palermo" merchant, so an unscoped comparison would
      # still pass even if the fix only worked by accident for seed data.
      lowercase_result = Merchant.search(neighborhood: "palermo").where(id: [ palermo.id, belgrano.id ])
      exact_case_result = Merchant.search(neighborhood: "Palermo").where(id: [ palermo.id, belgrano.id ])

      expect(lowercase_result).to contain_exactly(palermo)
      expect(exact_case_result).to contain_exactly(palermo)
      expect(lowercase_result.to_a).to eq(exact_case_result.to_a)
    end

    it "also matches an uppercase or mixed-case variant" do
      palermo = create_merchant(neighborhood: "Palermo")
      belgrano = create_merchant(neighborhood: "Belgrano")

      expect(Merchant.search(neighborhood: "PALERMO").where(id: [ palermo.id, belgrano.id ])).to contain_exactly(palermo)
      expect(Merchant.search(neighborhood: "pAlErMo").where(id: [ palermo.id, belgrano.id ])).to contain_exactly(palermo)
    end

    it "returns no results for a neighborhood that doesn't exist, in any casing" do
      palermo = create_merchant(neighborhood: "Palermo")

      expect(Merchant.search(neighborhood: "recoleta").where(id: palermo.id)).to be_empty
    end

    it "does not filter by neighborhood when blank" do
      palermo = create_merchant(neighborhood: "Palermo")
      belgrano = create_merchant(neighborhood: "Belgrano")

      expect(Merchant.search(neighborhood: nil)).to include(palermo, belgrano)
      expect(Merchant.search(neighborhood: "")).to include(palermo, belgrano)
    end
  end

  describe "type matching" do
    # Confirms `type` does NOT have the same casing risk as neighborhood/
    # tags: it's backed by a native Postgres enum (merchant_type_enum, see
    # db/structure.sql), constrained to a fixed set of lowercase keys, and
    # every caller already guarantees a normalized value reaches
    # Merchant.search — Api::V1::MerchantsController validates
    # `Merchant.types.key?(params[:type])` before calling .search, and
    # SearchQueryParser's response_schema restricts Gemini's "type" output
    # to `Merchant.types.keys`. So, unlike neighborhood, there is no
    # untrusted-casing path into this filter, and a mismatched-case value
    # can only reach here as a caller bug — which Postgres itself rejects
    # loudly (an exception, not a silent empty result), rather than
    # something Merchant.search needs to normalize away.
    it "matches the exact lowercase enum key" do
      restaurant = create_merchant(neighborhood: "Palermo")

      expect(Merchant.search(type: "restaurant")).to include(restaurant)
    end

    it "raises instead of silently matching nothing for a non-normalized value" do
      create_merchant(neighborhood: "Palermo")

      expect { Merchant.search(type: "RESTAURANT").to_a }.to raise_error(ActiveRecord::StatementInvalid)
    end
  end
end
