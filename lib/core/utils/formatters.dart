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