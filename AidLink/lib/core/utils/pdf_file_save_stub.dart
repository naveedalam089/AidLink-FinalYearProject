import 'dart:typed_data';

// --- Fallback implementation for unsupported platforms ---
Future<String> savePdfToDevice({
  required Uint8List bytes,
  required String fileName,
}) async {
  throw UnsupportedError('PDF saving is only supported on mobile and desktop.');
}
