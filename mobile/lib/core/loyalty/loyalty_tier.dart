import 'package:flutter/material.dart';

/// Loyalty tier presentation (label, hero gradient, text color) for a given
/// visit count, replicating `TIERS_L` from the design brief §1 / the design
/// prototype (`docs/design-reference/Fudo App.dc.html`).
///
/// DUPLICATION NOTE: `features/search/restaurant_detail_screen.dart` (out of
/// scope for the change that introduced this file — see that change's task
/// instructions) already has its own private, pixel-identical copy of this
/// exact gradient table and tier logic (`_LoyaltyTierInfo`,
/// `_tierForVisits`, `_clienteFijoGradient`, etc). This file is the shared
/// extraction used by new code (`features/my_places`); the detail screen was
/// deliberately left untouched rather than refactored to import from here.
/// If that constraint is lifted later, the detail screen's private copy
/// should be deleted in favor of this one so the table lives in exactly one
/// place.
@immutable
class LoyaltyTier {
  const LoyaltyTier({
    required this.label,
    required this.gradient,
    required this.textColor,
  });

  final String label;
  final Gradient gradient;
  final Color textColor;
}

const _clienteFijoGradient = LinearGradient(
  begin: Alignment(-0.5, -1),
  end: Alignment(0.5, 1),
  colors: [Color(0xFF1B1533), Color(0xFF3A2A78), Color(0xFF6E5AC8)],
  stops: [0, 0.48, 1],
);
const _nivelOroGradient = LinearGradient(
  begin: Alignment(-0.5, -1),
  end: Alignment(0.5, 1),
  colors: [Color(0xFF3B2A14), Color(0xFF7A5A1F), Color(0xFFE0B95C)],
  stops: [0, 0.45, 1],
);
const _nivelPlataGradient = LinearGradient(
  begin: Alignment(-0.5, -1),
  end: Alignment(0.5, 1),
  colors: [Color(0xFF1B1C2A), Color(0xFF33364B), Color(0xFF5A5F7D)],
  stops: [0, 0.55, 1],
);
const _nivelBronceGradient = LinearGradient(
  begin: Alignment(-0.5, -1),
  end: Alignment(0.5, 1),
  colors: [Color(0xFF2A160E), Color(0xFF7A3A1C), Color(0xFFE8703A)],
  stops: [0, 0.55, 1],
);
const _sinVisitasGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF1A1B26), Color(0xFF24263A)],
);

const _clienteFijo = LoyaltyTier(
  label: 'CLIENTE FIJO',
  gradient: _clienteFijoGradient,
  textColor: Color(0xFFD6CBFF),
);
const _nivelOro = LoyaltyTier(
  label: 'NIVEL ORO',
  gradient: _nivelOroGradient,
  textColor: Color(0xFFFFE9AE),
);
const _nivelPlata = LoyaltyTier(
  label: 'NIVEL PLATA',
  gradient: _nivelPlataGradient,
  textColor: Color(0xFFDCE2F0),
);
const _nivelBronce = LoyaltyTier(
  label: 'NIVEL BRONCE',
  gradient: _nivelBronceGradient,
  textColor: Color(0xFFFFC7B0),
);
const _sinVisitas = LoyaltyTier(
  label: 'SIN VISITAS AÚN',
  gradient: _sinVisitasGradient,
  textColor: Color(0x99FFFFFF),
);

/// Tier for a total visit count to ONE merchant, replicating `TIERS_L`
/// (capped at 10, same threshold table as the design brief §1 and the
/// restaurant detail screen's progress bar): Bronce ≥1, Plata ≥4, Oro ≥8,
/// Cliente fijo ≥10, "Sin visitas aún" at 0.
LoyaltyTier loyaltyTierForVisits(int visits) {
  final capped = visits > 10 ? 10 : visits;
  if (capped >= 10) return _clienteFijo;
  if (capped >= 8) return _nivelOro;
  if (capped >= 4) return _nivelPlata;
  if (capped >= 1) return _nivelBronce;
  return _sinVisitas;
}

/// The consumer's "top" loyalty tier across every merchant they've visited:
/// the tier for their highest single-merchant visit count. Since tiers are
/// strictly monotonic in visit count, the merchant with the most visits also
/// carries the consumer's highest tier — no need to compute a tier per
/// merchant and compare labels.
LoyaltyTier topLoyaltyTierForCounts(Iterable<int> visitCounts) {
  var max = 0;
  for (final count in visitCounts) {
    if (count > max) max = count;
  }
  return loyaltyTierForVisits(max);
}
