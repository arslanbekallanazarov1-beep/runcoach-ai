import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'run_card_export_result.dart';

Future<RunCardExportResult> exportRunCard({
  required Uint8List pngBytes,
  required String fileName,
  required String shareText,
}) async {
  final blob = web.Blob(
    [pngBytes.toJS].toJS,
    web.BlobPropertyBag(type: 'image/png'),
  );
  final objectUrl = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = objectUrl
    ..download = fileName
    ..title = shareText
    ..style.display = 'none';

  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  await Future<void>.delayed(const Duration(seconds: 1));
  web.URL.revokeObjectURL(objectUrl);
  return RunCardExportResult.downloaded;
}
