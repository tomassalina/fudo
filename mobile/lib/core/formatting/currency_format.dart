/// Shared number formatting helpers.
///
/// The "dot as thousands separator, no decimals" format (`16.000`, not
/// `16,000.00`) is the one convention used everywhere money shows up in this
/// app (gift card amounts, price-per-person ranges, menu item prices). It
/// was implemented independently in `features/gifting/gifting_screen.dart`
/// (`_formatCurrency`) and `features/search/widgets/search_utils.dart`
/// (`_formatMoney`) before this helper existed — those two call sites are
/// left as-is (out of scope for the change that added this file), but any
/// *new* code that needs this format should call [formatThousands] instead
/// of writing a fourth copy of the same loop.
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
