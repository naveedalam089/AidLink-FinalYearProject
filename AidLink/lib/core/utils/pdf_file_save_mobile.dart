import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

// --- Save PDF bytes to app documents directory ---
Future<String> savePdfToDevice({
  required Uint8List bytes,
  required String fileName,
}) async {
  final docsDir = await getApplicationDocumentsDirectory();
  final safeName = fileName.endsWith('.pdf') ? fileName : '$fileName.pdf';
  final file = File('${docsDir.path}/$safeName');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
