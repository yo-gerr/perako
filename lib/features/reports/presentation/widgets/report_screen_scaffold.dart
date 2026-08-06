import 'package:flutter/material.dart';

import 'export_dialog.dart';
import 'report_range_selector.dart';

/// Standard chrome for every report screen: an app bar with a CSV export
/// action and, by default, the shared range selector above the report body.
class ReportScreenScaffold extends StatelessWidget {
  const ReportScreenScaffold({
    super.key,
    required this.title,
    required this.child,
    this.csv,
    this.showRangeSelector = true,
  });

  final String title;
  final Widget child;
  final String? csv;
  final bool showRangeSelector;

  String get _filename =>
      '${title.toLowerCase().replaceAll(' ', '_')}.csv';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (csv != null)
            IconButton(
              icon: const Icon(Icons.ios_share),
              tooltip: 'Export CSV',
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => ExportDialog(filename: _filename, csv: csv!),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (showRangeSelector)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ReportRangeSelector(),
              ),
            ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
