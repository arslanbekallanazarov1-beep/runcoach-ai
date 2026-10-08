import 'dart:typed_data';

import 'run_card_export_result.dart';

Future<RunCardExportResult> exportRunCard({
  required Uint8List pngBytes,
  required String fileName,
  required String shareText,
}) {
  throw UnsupportedError('Run card export is not supported on this platform.');
}
