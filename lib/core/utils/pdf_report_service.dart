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
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return [
            _buildHeader(periodLabel),
            pw.SizedBox(height: 20),
            _buildStudentInfo(student),
            pw.SizedBox(height: 20),
            _buildResultsTable(results),
            pw.SizedBox(height: 20),
            _buildSummary(results),
            pw.SizedBox(height: 50),
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
              _buildHeader(periodLabel),
              pw.SizedBox(height: 20),
              _buildStudentInfo(student, batchName: batchName),
              pw.SizedBox(height: 20),
              _buildResultsTable(results),
              pw.SizedBox(height: 20),
              _buildSummary(results),
              pw.SizedBox(height: 50),
              _buildSignatures(),
            ];
          },
        ),
      );
    }

    return pdf.save();
  }

  static pw.Widget _buildHeader(String periodLabel) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text('STUDENT PROGRESS REPORT', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
        pw.SizedBox(height: 8),
        pw.Text('Report Period: $periodLabel', style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
        pw.SizedBox(height: 16),
        pw.Divider(thickness: 2, color: PdfColors.indigo900),
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
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _infoRow('Name:', student.name),
                if (student.rollNumber != null) _infoRow('Roll No:', student.rollNumber.toString()),
                if (student.className != null && student.className!.isNotEmpty) _infoRow('Class:', student.className!),
              ],
            ),
          ),
          if (batchName != null)
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _infoRow('Batch:', batchName),
                ],
              ),
            ),
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
          pw.SizedBox(width: 60, child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12))),
          pw.Expanded(child: pw.Text(value, style: const pw.TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  static pw.Widget _buildResultsTable(List<DetailedResult> results) {
    if (results.isEmpty) {
      return pw.Center(child: pw.Text('No exams taken in this period.'));
    }

    final dateFormat = DateFormat('dd MMM yyyy');

    return pw.TableHelper.fromTextArray(
      context: null,
      headers: ['Date', 'Exam Title', 'Type', 'Total Marks', 'Obtained Marks', 'Percentage'],
      data: results.map((r) {
        String obtainedStr = r.isAbsent ? 'Absent' : (r.obtainedMarks?.toCleanString() ?? '-');
        String percentageStr = '-';
        if (!r.isAbsent && r.obtainedMarks != null && r.totalMarks > 0) {
          percentageStr = '${((r.obtainedMarks! / r.totalMarks) * 100).toCleanString()}%';
        }
        return [
          dateFormat.format(r.examDate),
          r.examTitle,
          r.examType,
          r.totalMarks.toCleanString(),
          obtainedStr,
          percentageStr,
        ];
      }).toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
      rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
      cellAlignment: pw.Alignment.centerLeft,
      cellAlignments: {
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
      },
      cellStyle: const pw.TextStyle(fontSize: 10),
      headerHeight: 24,
      cellHeight: 20,
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
