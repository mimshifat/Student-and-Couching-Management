import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../../features/student/domain/entities/student.dart';
import '../../features/exam/domain/entities/detailed_result.dart';
import 'number_format_extension.dart';

class PdfReportService {
  static Future<Uint8List> generateStudentReport({
    required Student student,
    required List<DetailedResult> results,
    required String periodLabel,
    String? instituteName,
    String? ownerName,
    String? ownerPhone,
    String? batchName,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return [
            _buildHeader(periodLabel, instituteName: instituteName, ownerName: ownerName, ownerPhone: ownerPhone),
            pw.SizedBox(height: 12),
            _buildStudentInfo(student, batchName: batchName),
            pw.SizedBox(height: 12),
            _buildResultsTable(results, showBatchColumn: batchName == null || batchName.isEmpty),
            pw.SizedBox(height: 12),
            _buildSummary(results),
            pw.SizedBox(height: 40),
            _buildSignatures(),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> generateBatchReport({
    required String batchName,
    required Map<Student, List<DetailedResult>> studentResultsMap,
    required String periodLabel,
    String? instituteName,
    String? ownerName,
    String? ownerPhone,
  }) async {
    final pdf = pw.Document();

    for (var entry in studentResultsMap.entries) {
      final student = entry.key;
      final results = entry.value;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) {
            return [
              _buildHeader(periodLabel, instituteName: instituteName, ownerName: ownerName, ownerPhone: ownerPhone),
              pw.SizedBox(height: 12),
              _buildStudentInfo(student, batchName: batchName),
              pw.SizedBox(height: 12),
              _buildResultsTable(results, showBatchColumn: false),
              pw.SizedBox(height: 12),
              _buildSummary(results),
              pw.SizedBox(height: 40),
              _buildSignatures(),
            ];
          },
        ),
      );
    }

    return pdf.save();
  }

  static pw.Widget _buildHeader(String periodLabel, {String? instituteName, String? ownerName, String? ownerPhone}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (instituteName != null && instituteName.isNotEmpty) ...[
          pw.Text(instituteName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900), textAlign: pw.TextAlign.center),
          pw.SizedBox(height: 2),
        ],
        if ((ownerName != null && ownerName.isNotEmpty) || (ownerPhone != null && ownerPhone.isNotEmpty)) ...[
          pw.Text(
            [
              if (ownerName != null && ownerName.isNotEmpty) ownerName,
              if (ownerPhone != null && ownerPhone.isNotEmpty) 'Mobile: $ownerPhone'
            ].join(' | '),
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 8),
        ],
        pw.Text('STUDENT PROGRESS REPORT', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: (instituteName != null && instituteName.isNotEmpty) ? PdfColors.indigo700 : PdfColors.indigo900)),
        pw.SizedBox(height: 4),
        pw.Text('Report Period: $periodLabel', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.SizedBox(height: 12),
        pw.Divider(thickness: 1.5, color: PdfColors.indigo900),
      ],
    );
  }

  static pw.Widget _buildStudentInfo(Student student, {String? batchName}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 5,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _infoRow('Name:', student.name),
                if (student.className != null && student.className!.isNotEmpty) _infoRow('Class:', student.className!),
              ],
            ),
          ),
          if (batchName != null && batchName.isNotEmpty) ...[
            pw.SizedBox(width: 12),
            pw.Expanded(
              flex: 4,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _infoRow('Batch:', batchName),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }

  static pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(width: 45, child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
          pw.Expanded(child: pw.Text(value, style: const pw.TextStyle(fontSize: 10))),
        ],
      ),
    );
  }

  static pw.Widget _buildResultsTable(List<DetailedResult> results, {bool showBatchColumn = false}) {
    if (results.isEmpty) {
      return pw.Center(child: pw.Text('No exams taken in this period.'));
    }

    final dateFormat = DateFormat('dd MMM yyyy');

    List<String> headers = ['Date', 'Exam Title', 'Type', 'Obtained Marks', 'Total Marks', 'Percentage'];
    if (showBatchColumn) {
      headers.insert(1, 'Batch');
    }

    return pw.TableHelper.fromTextArray(
      context: null,
      headers: headers,
      data: results.map((r) {
        String obtainedStr = r.isAbsent ? 'Absent' : (r.obtainedMarks?.toCleanString() ?? '-');
        String percentageStr = '-';
        if (!r.isAbsent && r.obtainedMarks != null && r.totalMarks > 0) {
          percentageStr = '${((r.obtainedMarks! / r.totalMarks) * 100).toCleanString()}%';
        }
        
        List<String> row = [
          dateFormat.format(r.examDate),
          r.examTitle,
          r.examType,
          obtainedStr,
          r.totalMarks.toCleanString(),
          percentageStr,
        ];
        
        if (showBatchColumn) {
          row.insert(1, r.displayBatchName);
        }
        
        return row;
      }).toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
      rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
      cellAlignment: pw.Alignment.centerLeft,
      cellAlignments: showBatchColumn ? {
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
        6: pw.Alignment.centerRight,
      } : {
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
      },
      cellStyle: const pw.TextStyle(fontSize: 9),
      headerHeight: 22,
      cellHeight: 18,
      columnWidths: showBatchColumn ? {
        0: const pw.FixedColumnWidth(60), // Date
        1: const pw.FlexColumnWidth(2),   // Batch
        2: const pw.FlexColumnWidth(2.5), // Exam Title
        3: const pw.FlexColumnWidth(1.5), // Type
        4: const pw.FlexColumnWidth(1.5), // Obtained
        5: const pw.FlexColumnWidth(1.5), // Total
        6: const pw.FlexColumnWidth(1.5), // Percentage
      } : {
        0: const pw.FixedColumnWidth(60), // Date
        1: const pw.FlexColumnWidth(3.5), // Exam Title
        2: const pw.FlexColumnWidth(1.5), // Type
        3: const pw.FlexColumnWidth(1.5), // Obtained
        4: const pw.FlexColumnWidth(1.5), // Total
        5: const pw.FlexColumnWidth(1.5), // Percentage
      },
    );
  }

  static pw.Widget _buildSummary(List<DetailedResult> results) {
    int totalExams = results.length;
    int absents = results.where((r) => r.isAbsent).length;
    
    double totalAvailable = 0;
    double totalObtained = 0;
    
    for (var r in results) {
      if (!r.isAbsent && r.obtainedMarks != null) {
        totalAvailable += r.totalMarks;
        totalObtained += r.obtainedMarks!;
      }
    }
    
    double overallAvg = totalAvailable > 0 ? (totalObtained / totalAvailable) * 100 : 0.0;

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.indigo50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _summaryItem('Total Exams', totalExams.toString()),
          _summaryItem('Absents', absents.toString()),
          _summaryItem('Total Marks', '${totalObtained.toCleanString()} / ${totalAvailable.toCleanString()}'),
          _summaryItem('Overall %', '${overallAvg.toCleanString()}%'),
        ],
      ),
    );
  }

  static pw.Widget _summaryItem(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.SizedBox(height: 4),
        pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
      ],
    );
  }

  static pw.Widget _buildSignatures() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Container(width: 150, height: 1, color: PdfColors.black),
            pw.SizedBox(height: 4),
            pw.Text("Teacher's Signature", style: const pw.TextStyle(fontSize: 12)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Container(width: 150, height: 1, color: PdfColors.black),
            pw.SizedBox(height: 4),
            pw.Text("Guardian's Signature", style: const pw.TextStyle(fontSize: 12)),
            pw.SizedBox(height: 2),
            pw.Text("(Please sign and return)", style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          ],
        ),
      ],
    );
  }
}
