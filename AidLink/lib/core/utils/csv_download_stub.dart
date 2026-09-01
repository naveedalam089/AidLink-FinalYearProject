// --- Fallback implementation for non-web platforms ---
void downloadTextFile({
  required String content,
  required String fileName,
  String mimeType = 'text/plain;charset=utf-8',
  bool addBom = false,
}) {
  throw UnsupportedError('File download is only supported on web.');
}

// --- CSV helper built on top of text file download ---
void downloadCsvFile({required String content, required String fileName}) {
  downloadTextFile(
    content: content,
    fileName: fileName,
    mimeType: 'text/csv;charset=utf-8',
    addBom: true,
  );
}
