import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../domain/entities/annual_report_entry.dart';
import '../../domain/repositories/enrollment_repository.dart';

class AnnualReportProvider with ChangeNotifier {
  final EnrollmentRepository _repository;

  AnnualReportProvider(this._repository);

  int _selectedYear = DateTime.now().year;
  int get selectedYear => _selectedYear;

  List<int> _availableYears = [];
  List<int> get availableYears => _availableYears;

  List<AnnualReportEntry> _entries = [];
  List<AnnualReportEntry> get entries => _entries;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ── public API ────────────────────────────────────────────────────────────

  Future<void> loadReport(int year) async {
    _selectedYear = year;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Load available years on first call (or if empty)
      if (_availableYears.isEmpty) {
        _availableYears = await _repository.getDistinctEnrollmentYears();
        // Ensure selectedYear is in the list; if not, use the first available
        if (_availableYears.isNotEmpty && !_availableYears.contains(_selectedYear)) {
          _selectedYear = _availableYears.first;
        }
      }
      final rows = await _repository.getEnrollmentsByYear(_selectedYear);
      _entries = _groupRows(rows);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Exports the annual report as a PDF using the system print/save dialog.
  Future<void> exportToPdf() async {
    final doc = pw.Document();

    final reportTitle = 'Annual Student Enrollment Report - $_selectedYear';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildPdfHeader(reportTitle),
            pw.SizedBox(height: 20),
            _buildPdfTable(),
          ];
        },
        footer: (pw.Context context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generated: ${DateTime.now().toLocal().toString().split('.').first}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Annual_Report_$_selectedYear.pdf',
    );
  }

  // ── grouping ──────────────────────────────────────────────────────────────

  List<AnnualReportEntry> _groupRows(List<Map<String, dynamic>> rows) {
    final Map<int, AnnualReportEntry> map = {};

    for (final row in rows) {
      final studentId = row['student_id'] as int;
      final batchInfo = BatchInfo(
        batchName: row['batch_name_snapshot'] as String?,
        studentClass: row['student_class'] as String?,
        scheduleDays: row['schedule_days'] as String?,
        timeSlot: row['time_slot'] as String?,
      );

      if (map.containsKey(studentId)) {
        // Append batch to existing entry
        final existing = map[studentId]!;
        map[studentId] = AnnualReportEntry(
          studentId: existing.studentId,
          studentName: existing.studentName,
          phone: existing.phone,
          batches: [...existing.batches, batchInfo],
        );
      } else {
        map[studentId] = AnnualReportEntry(
          studentId: studentId,
          studentName: row['student_name'] as String? ?? '[Deleted Student]',
          phone: row['phone'] as String?,
          batches: [batchInfo],
        );
      }
    }

    return map.values.toList();
  }

  // ── PDF builder helpers ───────────────────────────────────────────────────

  pw.Widget _buildPdfHeader(String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generated on: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            pw.Text(
              'Total Students: ${_entries.length}',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Report Year: $_selectedYear',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(color: PdfColors.grey400),
      ],
    );
  }

  pw.Widget _buildPdfTable() {
    final headers = ['#', 'Name', 'Phone', 'Class', 'Batch', 'Schedule'];
    final colWidths = <int, pw.TableColumnWidth>{
      0: const pw.FixedColumnWidth(24),
      1: const pw.FlexColumnWidth(2.5),
      2: const pw.FlexColumnWidth(2),
      3: const pw.FlexColumnWidth(1.5),
      4: const pw.FlexColumnWidth(2),
      5: const pw.FlexColumnWidth(2),
    };
    const cellPad = pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5);
    final headerStyle = pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.white);

    if (_entries.isEmpty) {
      return pw.Center(
        child: pw.Text(
          'No students enrolled for $_selectedYear.',
          style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey600),
        ),
      );
    }

    final data = _entries.asMap().entries.map((e) {
      final index = e.key;
      final entry = e.value;
      final classText = entry.batches.map((b) => b.studentClass ?? '-').join('\n');
      final batchText = entry.batches.map((b) => b.batchName ?? '-').join('\n');
      final scheduleText = entry.batches.map((b) {
        final parts = [b.scheduleDays, b.timeSlot]
            .where((s) => s != null && s.isNotEmpty)
            .join(' ');
        return parts.isEmpty ? '-' : parts;
      }).join('\n');

      return ['${index + 1}', entry.studentName, entry.phone ?? '-', classText, batchText, scheduleText];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      headerStyle: headerStyle,
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
      cellStyle: const pw.TextStyle(fontSize: 9, color: PdfColors.black),
      cellPadding: cellPad,
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerLeft,
        4: pw.Alignment.centerLeft,
        5: pw.Alignment.centerLeft,
      },
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
      columnWidths: colWidths,
    );
  }


}
