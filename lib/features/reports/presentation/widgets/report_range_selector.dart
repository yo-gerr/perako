import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/reports_providers.dart';

/// Chip row that switches the shared report window between quick presets.
class ReportRangeSelector extends ConsumerWidget {
  const ReportRangeSelector({super.key});

  static const _presets = <(String, Duration?)>[
    ('3M', Duration(days: 90)),
    ('6M', Duration(days: 180)),
    ('1Y', Duration(days: 365)),
    ('All', null),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(reportsRangeProvider);
    final now = DateTime.now();

    return Wrap(
      spacing: 8,
      children: [
        for (final (label, span) in _presets)
          ChoiceChip(
            label: Text(label),
            selected: _matches(range.from, now, span),
            onSelected: (_) {
              final from = span == null
                  ? DateTime(now.year - 5, now.month, now.day)
                  : now.subtract(span);
              ref
                  .read(reportsRangeProvider.notifier)
                  .setRange(from, DateTime.now());
            },
          ),
      ],
    );
  }

  bool _matches(DateTime from, DateTime now, Duration? span) {
    if (span == null) {
      return from.year <= now.year - 5;
    }
    final expected = now.subtract(span).millisecondsSinceEpoch;
    return (from.millisecondsSinceEpoch - expected).abs() <
        const Duration(days: 2).inMilliseconds;
  }
}
