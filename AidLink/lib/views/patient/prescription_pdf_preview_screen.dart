import 'dart:typed_data';

// Purpose: Patient screen for previewing and exporting prescriptions as PDF.
// File: lib/views/patient/prescription_pdf_preview_screen.dart

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../core/constants/colors.dart';

class PrescriptionPdfPreviewScreen extends StatelessWidget {
  final String title;
  final Uint8List pdfBytes;

  const PrescriptionPdfPreviewScreen({
    Key? key,
    required this.title,
    required this.pdfBytes,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // --- Build PDF preview with print/share options ---
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      // --- PDF viewer with printing and sharing ---
      body: PdfPreview(
        build: (_) async => pdfBytes,
        allowPrinting: true,
        allowSharing: true,
      ),
    );
  }
}
