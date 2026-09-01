// Purpose: Platform-agnostic CSV download helper (auto-routes to web or mobile version).
// File: lib/core/utils/csv_download.dart

// --- Conditional export for web/non-web CSV download helpers ---
export 'csv_download_stub.dart' if (dart.library.html) 'csv_download_web.dart';
