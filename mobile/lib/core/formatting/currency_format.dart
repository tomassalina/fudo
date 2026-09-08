/// Shared number formatting helpers.
///
/// The "dot as thousands separator, no decimals" format (`16.000`, not
/// `16,000.00`) is the one convention used everywhere money shows up in this
/// app (gift card amounts, price-per-person ranges, menu item prices), per
/// `docs/design-brief.md` §1/§2.6 (e.g. `$121.000`, `$1.000.000`). It used to
/// be implemented independently in `features/gifting/gifting_screen.dart`
/// (`_formatCurrency`) and `features/search/widgets/search_utils.dart`
/// (`formatMoney`) — both were byte-for-byte the same loop as the one below,
/// just with the `$` baked in, so they were folded into [formatCurrency]
/// here. Callers keep their own public wrapper where an existing import
/// (e.g. `search_utils.dart`'s `formatMoney`) is still relied on elsewhere.
library;

/// Formats [value] as an integer with `.` thousands separators, e.g.
/// `formatThousands(16000)` → `"16.000"`. Callers add their own currency
/// prefix/suffix (`$`, `ARS`, `US$`, ...) since that varies by context.
String formatThousands(num value) {
  final digits = value.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final fromEnd = digits.length - i;
    if (i != 0 && fromEnd % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Formats [value] as Argentine-style pesos with a `$` prefix (no space)
/// and `.` thousands separators, e.g. `formatCurrency(121000)` →
/// `"$121.000"`. This is [formatThousands] plus the `$` that both former
/// call sites (`_formatCurrency` in `gifting_screen.dart` and `formatMoney`
/// in `search_utils.dart`) prepended identically.
String formatCurrency(num value) => '\$${formatThousands(value)}';
