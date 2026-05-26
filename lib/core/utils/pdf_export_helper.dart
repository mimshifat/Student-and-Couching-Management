import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../features/student/domain/entities/student.dart';
import '../../../features/fee/domain/entities/fee_record.dart';

class PdfExportHelper {
  static Future<void> exportStudentReport(Student student, List<FeeRecord> feeRecords) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(level: 0, child: pw.Text('Student Report: ${student.name}')),
              pw.SizedBox(height: 16),
              pw.Text('Personal Information', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
              pw.Divider(),
              pw.Text('Phone: ${student.phone ?? "N/A"}'),
              pw.Text('Guardian: ${student.guardianName ?? "N/A"} (${student.guardianRelation ?? "N/A"})'),
              pw.Text('Guardian Phone: ${student.guardianPhone ?? "N/A"}'),
              pw.SizedBox(height: 16),
              pw.Text('Academic Information', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
              pw.Divider(),
              pw.Text('School/College: ${student.schoolCollege ?? "N/A"}'),
              pw.Text((student.className?.toLowerCase().startsWith('class') ?? false) ? student.className! : 'Class: ${student.className ?? "N/A"}'),
              pw.Text('Roll Number: ${student.rollNumber ?? "N/A"}'),
              pw.SizedBox(height: 24),
              pw.Text('Fee History', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
              pw.Divider(),
              if (feeRecords.isEmpty)
                pw.Text('No fee records found.')
              else
                pw.TableHelper.fromTextArray(
                  headers: ['Month/Year', 'Total', 'Paid', 'Due'],
                  data: feeRecords.map((r) => [
                    '${r.month} ${r.year}',
                    'BDT ${r.totalAmount.toStringAsFixed(0)}',
                    'BDT ${r.paidAmount.toStringAsFixed(0)}',
                    'BDT ${(r.totalAmount - r.paidAmount).toStringAsFixed(0)}',
                  ]).toList(),
                ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '${student.name.replaceAll(' ', '_')}_Report.pdf',
    );
  }
}
