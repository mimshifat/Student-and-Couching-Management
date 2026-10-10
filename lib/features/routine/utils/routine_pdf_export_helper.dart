import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

import '../domain/entities/routine.dart';
import '../../batch/domain/entities/batch.dart';

class RoutinePdfExportHelper {
  static Future<void> generateAndPreviewRoutinePdf(
      List<Batch> batches, List<Routine> allRoutines, String instituteName) async {
    final pdf = pw.Document();

    final fullDays = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday'
    ];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildHeader(instituteName),
            pw.SizedBox(height: 20),
            _buildRoutineTable(fullDays, batches, allRoutines),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Weekly_Routine.pdf',
    );
  }

  static pw.Widget _buildHeader(String instituteName) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(instituteName,
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Text('Full Weekly Routine',
            style: pw.TextStyle(fontSize: 18, color: PdfColors.grey700)),
        pw.Divider(),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
                'Generated on: ${DateFormat('MMM dd, yyyy').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 12)),
          ],
        ),
        pw.SizedBox(height: 12),
      ],
    );
  }

  static pw.Widget _buildRoutineTable(
      List<String> fullDays, List<Batch> batches, List<Routine> allRoutines) {
    List<pw.TableRow> tableRows = [];

    // Header Row
    tableRows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.black, width: 1.5),
          ),
        ),
        children: [
          _buildCell('Day', isHeader: true),
          _buildCell('Batch Name', isHeader: true),
          _buildCell('Subject', isHeader: true),
          _buildCell('Time', isHeader: true),
        ],
      ),
    );

    for (var day in fullDays) {
      final routinesForDay = allRoutines.where((r) => r.dayOfWeek == day).toList();
      if (routinesForDay.isEmpty) continue;

      for (int i = 0; i < routinesForDay.length; i++) {
        final r = routinesForDay[i];
        final batch = batches.firstWhere(
          (b) => b.id == r.batchId,
          orElse: () => Batch(
              name: 'Unknown Batch',
              createdAt: DateTime.now()),
        );

        String timeStr = '';
        if (r.startTime.isNotEmpty && r.endTime.isNotEmpty) {
          timeStr = '${r.startTime} - ${r.endTime}';
        } else {
          timeStr = batch.timeSlot ?? '';
          if (timeStr.isEmpty &&
              batch.startTime != null &&
              batch.startTime!.isNotEmpty &&
              batch.endTime != null &&
              batch.endTime!.isNotEmpty) {
            timeStr = '${batch.startTime} - ${batch.endTime}';
          }
        }

        // Only print the day name on the first row for that day
        final dayText = (i == 0) ? day : '';
        bool isLastOfDay = (i == routinesForDay.length - 1);

        tableRows.add(
          pw.TableRow(
            children: [
              _buildCell(dayText, isDaySeparator: isLastOfDay),
              _buildCell(batch.name, isDaySeparator: isLastOfDay, isInnerSeparator: !isLastOfDay),
              _buildCell(r.subject, isDaySeparator: isLastOfDay, isInnerSeparator: !isLastOfDay),
              _buildCell(timeStr, isDaySeparator: isLastOfDay, isInnerSeparator: !isLastOfDay),
            ],
          ),
        );
      }
    }

    return pw.Table(
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.full,
      columnWidths: {
        0: const pw.FlexColumnWidth(1.2),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(2),
      },
      children: tableRows,
    );
  }

  static pw.Widget _buildCell(String text,
      {bool isHeader = false,
      bool isDaySeparator = false,
      bool isInnerSeparator = false}) {
    pw.BoxBorder? border;
    if (isDaySeparator) {
      border = const pw.Border(
          bottom: pw.BorderSide(color: PdfColors.black, width: 1.0));
    } else if (isInnerSeparator) {
      border = const pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.5));
    }

    return pw.Container(
      alignment: pw.Alignment.centerLeft,
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: pw.BoxDecoration(border: border),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: isHeader ? 12 : 11,
        ),
      ),
    );
  }
}
