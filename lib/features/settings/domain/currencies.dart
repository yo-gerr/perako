/// A currency selectable in settings, with its ISO code and display symbol.
class Currency {
  const Currency(this.code, this.symbol, this.name);

  final String code;
  final String symbol;
  final String name;
}

/// Currencies offered in settings. Kept small and local-first; no network
/// rates are involved since PeraKo only formats local values.
const List<Currency> supportedCurrencies = [
  Currency('PHP', '₱', 'Philippine Peso'),
  Currency('USD', r'$', 'US Dollar'),
  Currency('EUR', '€', 'Euro'),
  Currency('GBP', '£', 'British Pound'),
  Currency('JPY', '¥', 'Japanese Yen'),
  Currency('SGD', r'S$', 'Singapore Dollar'),
  Currency('AUD', r'A$', 'Australian Dollar'),
  Currency('CAD', r'C$', 'Canadian Dollar'),
  Currency('AED', 'د.إ', 'UAE Dirham'),
];

/// Symbol used to format money for [code]; falls back to the code itself so
/// an unknown currency still renders unambiguously.
String currencySymbol(String code) {
  for (final c in supportedCurrencies) {
    if (c.code == code) return c.symbol;
  }
  return '$code ';
}

/// Human-readable name for [code]; falls back to the code itself.
String currencyName(String code) {
  for (final c in supportedCurrencies) {
    if (c.code == code) return c.name;
  }
  return code;
}
