import 'dart:convert';
import 'dart:html' as html;

// --- Web downloader using Blob and hidden anchor ---
void downloadTextFile({
  required String content,
  required String fileName,
  String mimeType = 'text/plain;charset=utf-8',
  bool addBom = false,
}) {
  final normalized = addBom ? '\uFEFF$content' : content;
  final bytes = utf8.encode(normalized);
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);

  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';

  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}

// --- CSV helper built on top of text download ---
void downloadCsvFile({required String content, required String fileName}) {
  downloadTextFile(
    content: content,
    fileName: fileName,
    mimeType: 'text/csv;charset=utf-8',
    addBom: true,
  );
}
