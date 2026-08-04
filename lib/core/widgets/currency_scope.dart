import 'package:flutter/widgets.dart';

/// Provides the active currency symbol (from settings) to descendant widgets,
/// so `formatMoney` call sites can render the user's currency via `context`.
class CurrencyScope extends InheritedWidget {
  const CurrencyScope({super.key, required this.symbol, required super.child});

  final String symbol;

  static String of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<CurrencyScope>();
    return scope?.symbol ?? '₱';
  }

  @override
  bool updateShouldNotify(CurrencyScope oldWidget) =>
      oldWidget.symbol != symbol;
}
