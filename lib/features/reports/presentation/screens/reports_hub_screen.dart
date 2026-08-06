import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Picker for the five report screens.
class ReportsHubScreen extends StatelessWidget {
  const ReportsHubScreen({super.key});

  static const _reports = <(IconData, String, String, String)>[
    (
      Icons.trending_up,
      'Net Worth',
      'Balance across all accounts over time',
      '/reports/net-worth',
    ),
    (
      Icons.swap_vert,
      'Cash Flow',
      'Income vs spending per period',
      '/reports/cash-flow',
    ),
    (
      Icons.pie_chart_outline,
      'Spending by Category',
      'Where your money went',
      '/reports/spending',
    ),
    (
      Icons.attach_money,
      'Income by Category',
      'Where your money came from',
      '/reports/income',
    ),
    (
      Icons.speed,
      'Budget Performance',
      'How budgets track against their targets',
      '/reports/budget-performance',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Text(
              'Derived live from your ledger. Export any report as CSV.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          for (final (icon, title, subtitle, route) in _reports)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListTile(
                leading: Icon(icon),
                title: Text(title),
                subtitle: Text(subtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(route),
              ),
            ),
        ],
      ),
    );
  }
}
