// Triggers a CSV download. On the web this streams a Blob download; on
// native platforms it writes the file into the app documents directory and
// returns the written path.
export 'csv_download_native.dart' if (dart.library.html) 'csv_download_web.dart';
