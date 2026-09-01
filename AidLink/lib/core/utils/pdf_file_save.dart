// Purpose: Platform-agnostic PDF file save helper (auto-routes to web or mobile version).
// File: lib/core/utils/pdf_file_save.dart

// --- Conditional export for supported PDF save implementation ---
export 'pdf_file_save_stub.dart'
    if (dart.library.io) 'pdf_file_save_mobile.dart';
