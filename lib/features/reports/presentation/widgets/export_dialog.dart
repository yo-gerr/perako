import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/csv_download.dart';

/// Offers the only two export targets PeraKo ships: a CSV file download and a
/// clipboard copy.
class ExportDialog extends StatelessWidget {
  const ExportDialog({
    super.key,
    required this.filename,
    required this.csv,
  });

  final String filename;
  final String csv;

  Future<void> _download(BuildContext context) async {
    try {
      final path = await downloadCsv(filename: filename, contents: csv);
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved CSV to $path')),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: csv));
    if (!context.mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Export'),
      content: const Text('Choose a destination for this report as CSV.'),
      actions: [
        TextButton(
          onPressed: () => _copy(context),
          child: const Text('Copy'),
        ),
        FilledButton(
          onPressed: () => _download(context),
          child: const Text('Download CSV'),
        ),
      ],
    );
  }
}
