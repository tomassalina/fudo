// Coarse loyalty tier derivation — mirrors `tierOf()` in both design
// references (`docs/design-reference/Fudo App.dc.html` and
// `Fudo Customers.dc.html`). Pure and merchant-agnostic: a badge purely off
// total visit count, independent of any one merchant's own reward ladder.
// Moved here from lib/mock/visit-history.ts (deleted) once ProfileHeader/
// PerfilView started deriving it from real visit counts instead of mock
// ones — this logic was never mock-specific to begin with.

import type { VisitTier } from "@/lib/types";

export function tierForVisits(visits: number): VisitTier {
  if (visits >= 8) return "Oro";
  if (visits >= 4) return "Plata";
  return "Bronce";
}
