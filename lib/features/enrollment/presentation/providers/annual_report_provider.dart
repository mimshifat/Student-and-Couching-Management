import 'package:flutter/foundation.dart';
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

  /// Shares/prints the annual report as a PDF.
  Future<void> exportToPdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        header: (_) => _pdfHeader(),
        footer: (ctx) => _pdfFooter(ctx),
        build: (ctx) => [
          _pdfSummary(),
          pw.SizedBox(height: 16),
          _pdfTable(),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'annual_report_$_selectedYear.pdf',
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

  // ── PDF helpers ───────────────────────────────────────────────────────────

  pw.Widget _pdfHeader() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'বার্ষিক রিপোর্ট - $_selectedYear',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Divider(thickness: 1.5),
        pw.SizedBox(height: 4),
      ],
    );
  }

  pw.Widget _pdfFooter(pw.Context ctx) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'Generated: ${DateTime.now().toLocal().toString().split('.').first}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
        pw.Text(
          'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      ],
    );
  }

  pw.Widget _pdfSummary() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        'মোট ছাত্রছাত্রী: ${_entries.length} জন',
        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  pw.Widget _pdfTable() {
    // ignore: prefer_const_declarations
    final headerStyle = pw.TextStyle(fontWeight: pw.FontWeight.bold);
    final cellPad = const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5);

    final headers = ['#', 'নাম', 'ফোন', 'ক্লাস', 'ব্যাচ', 'সময়সূচী'];
    final colWidths = [
      const pw.FixedColumnWidth(24),
      const pw.FlexColumnWidth(2.5),
      const pw.FlexColumnWidth(2),
      const pw.FlexColumnWidth(1.5),
      const pw.FlexColumnWidth(2),
      const pw.FlexColumnWidth(2),
    ];

    // Build rows — one student per row; multiple batches stacked with newlines
    final dataRows = <pw.TableRow>[];

    for (int i = 0; i < _entries.length; i++) {
      final entry = _entries[i];

      final classText = entry.batches
          .map((b) => b.studentClass ?? '-')
          .join('\n');
      final batchText = entry.batches
          .map((b) => b.batchName ?? '-')
          .join('\n');
      final scheduleText = entry.batches.map((b) {
        final parts = [b.scheduleDays, b.timeSlot]
            .where((s) => s != null && s.isNotEmpty)
            .join(' ');
        return parts.isEmpty ? '-' : parts;
      }).join('\n');

      final isEven = i % 2 == 0;
      final bg = isEven ? PdfColors.white : PdfColors.grey100;

      dataRows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(color: bg),
          children: [
            _cell('${i + 1}', cellPad),
            _cell(entry.studentName, cellPad),
            _cell(entry.phone ?? '-', cellPad),
            _cell(classText, cellPad),
            _cell(batchText, cellPad),
            _cell(scheduleText, cellPad),
          ],
        ),
      );
    }

    return pw.Table(
      columnWidths: {
        for (int i = 0; i < colWidths.length; i++) i: colWidths[i],
      },
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blue700),
          children: headers
              .map((h) => pw.Padding(
                    padding: cellPad,
                    child: pw.Text(h,
                        style: headerStyle.copyWith(color: PdfColors.white)),
                  ))
              .toList(),
        ),
        ...dataRows,
      ],
    );
  }

  pw.Widget _cell(String text, pw.EdgeInsets padding) {
    return pw.Padding(
      padding: padding,
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
    );
  }
}
