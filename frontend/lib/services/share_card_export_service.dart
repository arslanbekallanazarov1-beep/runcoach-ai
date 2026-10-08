import 'dart:typed_data';

import 'share_card_exporter_stub.dart'
    if (dart.library.io) 'share_card_exporter_native.dart'
    if (dart.library.html) 'share_card_exporter_web.dart' as exporter;

import 'run_card_export_result.dart';

Future<RunCardExportResult> exportRunCard({
  required Uint8List pngBytes,
  required String fileName,
  required String shareText,
}) {
  return exporter.exportRunCard(
    pngBytes: pngBytes,
    fileName: fileName,
    shareText: shareText,
  );
}
