import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import 'run_card_export_result.dart';

Future<RunCardExportResult> exportRunCard({
  required Uint8List pngBytes,
  required String fileName,
  required String shareText,
}) async {
  final imageFile = XFile.fromData(
    pngBytes,
    name: fileName,
    mimeType: 'image/png',
  );
  final result = await SharePlus.instance.share(
    ShareParams(files: [imageFile], text: shareText),
  );
  return switch (result.status) {
    ShareResultStatus.success => RunCardExportResult.shared,
    ShareResultStatus.dismissed => RunCardExportResult.dismissed,
    ShareResultStatus.unavailable => RunCardExportResult.shareStatusUnavailable,
  };
}
