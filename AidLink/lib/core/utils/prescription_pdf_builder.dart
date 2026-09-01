// Purpose: Builds prescription PDF documents for display and export.
// File: lib/core/utils/prescription_pdf_builder.dart

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// --- Data container for prescription information ---
class PrescriptionPdfData {
  final String doctorName;
  final String patientName;
  final DateTime date;
  final String diagnosis;
  final String advice;
  final String? followUpDateText;
  final List<Map<String, String>> medicines;

  const PrescriptionPdfData({
    required this.doctorName,
    required this.patientName,
    required this.date,
    required this.diagnosis,
    required this.advice,
    required this.medicines,
    this.followUpDateText,
  });
}

// --- Helper: Format date as DD/MM/YYYY ---
String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

// --- Build prescription PDF from data ---
Future<Uint8List> buildPrescriptionPdf(PrescriptionPdfData data) async {
  final doc = pw.Document();

  doc.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
        ),
      ),
      build: (_) {
        return [
          // --- Header with title and date ---
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: PdfColors.green600,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'AidLink Prescription',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  _formatDate(data.date),
                  style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          // --- Doctor, patient, diagnosis info ---
          pw.Text(
            'Doctor: ${data.doctorName}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text('Patient: ${data.patientName}'),
          pw.SizedBox(height: 6),
          pw.Text(
            'Diagnosis: ${data.diagnosis.isEmpty ? 'Not specified' : data.diagnosis}',
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Follow Up: ${data.followUpDateText == null || data.followUpDateText!.isEmpty ? 'Not specified' : data.followUpDateText}',
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            'Medicines',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
          ),
          pw.SizedBox(height: 8),
          // Build medicine table or empty message
          data.medicines.isEmpty
              ? pw.Text('No medicines listed.')
              : pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(2),
                    3: const pw.FlexColumnWidth(2),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.green50,
                      ),
                      children: [
                        _cell('Medicine', true),
                        _cell('Dosage', true),
                        _cell('Frequency', true),
                        _cell('Duration', true),
                      ],
                    ),
                    ...data.medicines.map((m) {
                      return pw.TableRow(
                        children: [
                          _cell(m['name'] ?? '-'),
                          _cell(m['dosage'] ?? '-'),
                          _cell(m['frequency'] ?? '-'),
                          _cell(m['duration'] ?? '-'),
                        ],
                      );
                    }),
                  ],
                ),
          pw.SizedBox(height: 14),
          // --- Doctor advice section ---
          pw.Text(
            'Doctor Advice',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
          ),
          pw.SizedBox(height: 6),
          // Advice text or placeholder
          pw.Text(data.advice.isEmpty ? 'No advice provided.' : data.advice),
        ];
      },
    ),
  );

  // Return PDF as bytes
  return doc.save();
}

// --- Helper: Create table cell with optional bold formatting ---
pw.Widget _cell(String value, [bool header = false]) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(8),
    child: pw.Text(
      value,
      style: pw.TextStyle(
        fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
        fontSize: 10,
      ),
    ),
  );
}
