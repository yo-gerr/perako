/// Formats an integer amount in cents as a currency string.
///
/// Perako stores money as integer cents (Perako convention). This helper
/// renders a human-readable value, e.g. `52500` -> `₱525.00`.
String formatMoney(int cents, {String symbol = '₱'}) {
  final sign = cents < 0 ? '-' : '';
  final abs = cents.abs();
  final pesos = abs ~/ 100;
  final centavos = (abs % 100).toString().padLeft(2, '0');
  return '$sign$symbol$pesos.$centavos';
}

/// Parses a user-typed money string into integer cents.
///
/// Returns null when the value is missing, unparseable, or not positive.
/// Commas are treated as thousands separators.
int? parseMoneyCents(String raw) {
  final value = double.tryParse(raw.trim().replaceAll(',', ''));
  if (value == null || value <= 0) return null;
  return (value * 100).round();
}