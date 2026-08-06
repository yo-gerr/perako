import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Streams [contents] to the browser as a download named [filename].
Future<String> downloadCsv({
  required String filename,
  required String contents,
}) async {
  final blob = web.Blob(
    [contents.toJS].toJS,
    web.BlobPropertyBag(type: 'text/csv'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  anchor.click();
  web.URL.revokeObjectURL(url);
  return filename;
}
