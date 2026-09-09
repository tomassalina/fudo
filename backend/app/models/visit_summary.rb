class VisitSummary < ApplicationRecord
  # Label used when a consumer hasn't reached any of the merchant's
  # loyalty_rules yet — same literal db/seeds.rb uses (see .tier_for below).
  NEW_TIER = "Nuevo"

  belongs_to :consumer
  # Merchant has a soft-delete default_scope, and belongs_to_required_by_default
  # (Rails 7.2+) revalidates presence on every save. Without unscoping
  # deleted_at here, a visit summary whose merchant later gets soft-deleted
  # would fail every future save with "Merchant must exist" — the
  # merchant_id column itself is still required, this only lets the
  # association keep resolving to a soft-deleted merchant instead of
  # finding none at all.
  belongs_to :merchant, -> { unscope(where: :deleted_at) }

  validates :count, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :consumer_id, uniqueness: { scope: :merchant_id }
  # current_tier is a free-text varchar(100) at the DB level (see
  # db/structure.sql) with no CHECK constraint or canonical enum — tiers are
  # derived per-merchant from that merchant's own loyalty_rules, not a
  # fixed global list. VisitSummariesController is the only place that
  # assigns current_tier, and it always computes it from real data via
  # .tier_for (never trusts the client — see the controller's comment on
  # #assign_computed_progress). This validation is defense-in-depth so an
  # arbitrary string can never land in this column through any other path
  # either, while still allowing every label the merchant's real
  # loyalty_rules can actually produce right now.
  validates :current_tier, inclusion: { in: ->(summary) { summary.valid_tiers } }, allow_nil: true, if: -> { merchant.present? }

  # The tier labels this visit summary's merchant can legitimately produce
  # right now: NEW_TIER (no loyalty_rules reached yet) plus one
  # "Nivel N visitas" per real, non-deleted loyalty_rule the merchant has.
  def valid_tiers
    [ NEW_TIER ] + merchant.loyalty_rules.pluck(:visits_required).map { |visits_required| "Nivel #{visits_required} visitas" }
  end

  # The tier label a consumer with `visit_count` real visits at `merchant`
  # has actually reached — the highest loyalty_rule whose visits_required
  # they've met, or NEW_TIER if none yet. Same algorithm db/seeds.rb uses to
  # build demo data (see "Visit summaries" section there), extracted here so
  # VisitSummariesController can compute real progress instead of trusting
  # the client for it.
  def self.tier_for(merchant, visit_count)
    highest_reached = merchant.loyalty_rules.order(:visits_required).select { |rule| rule.visits_required <= visit_count }.last
    highest_reached ? "Nivel #{highest_reached.visits_required} visitas" : NEW_TIER
  end
end
