import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Writes [contents] to `{documentsDir}/[filename]` and returns the path.
Future<String> downloadCsv({
  required String filename,
  required String contents,
}) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsString(contents);
  return file.path;
}
