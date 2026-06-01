import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class FeeReportPdfGenerator {
  static Future<void> generateAndPrintReport({
    required int month,
    required int year,
    required List<Map<String, dynamic>> transactions,
  }) async {
    final doc = pw.Document();
    
    final monthName = DateFormat('MMMM').format(DateTime(year, month));
    final reportTitle = 'Fee Collection Report - $monthName $year';
    
    double totalCollected = 0.0;
    for (var t in transactions) {
      totalCollected += (t['transaction_amount'] as num).toDouble();
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildHeader(reportTitle, monthName, year, transactions.length, totalCollected),
            pw.SizedBox(height: 20),
            _buildTransactionTable(transactions),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Fee_Collection_Report_${monthName}_$year.pdf',
    );
  }

  static pw.Widget _buildHeader(String title, String monthName, int year, int studentCount, double totalCollected) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Generated on: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            pw.Text('Total Transactions: $studentCount', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          ]
        ),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Collection Month: $monthName $year', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            pw.Text('Total Collected: ৳${totalCollected.toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
          ]
        ),
        pw.SizedBox(height: 10),
        pw.Divider(color: PdfColors.grey400),
      ],
    );
  }

  static pw.Widget _buildTransactionTable(List<Map<String, dynamic>> transactions) {
    if (transactions.isEmpty) {
      return pw.Center(
        child: pw.Text('No transactions found for this month.', style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey600)),
      );
    }

    final headers = [
      'Date',
      'Student Name',
      'Batch',
      'Fee Month',
      'Amount'
    ];

    final data = transactions.map((t) {
      final dateStr = t['payment_date'] as String;
      final date = DateTime.tryParse(dateStr);
      final formattedDate = date != null ? DateFormat('dd MMM').format(date) : dateStr;
      
      final feeMonth = t['fee_month'] as int;
      final feeYear = t['fee_year'] as int;
      final feeMonthName = DateFormat('MMM').format(DateTime(feeYear, feeMonth));
      final feeFor = '$feeMonthName $feeYear';

      return [
        formattedDate,
        t['student_name'] ?? 'Unknown',
        t['batch_details_snapshot'] ?? '-',
        feeFor,
        '৳${(t['transaction_amount'] as num).toStringAsFixed(0)}',
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
      cellStyle: const pw.TextStyle(fontSize: 9, color: PdfColors.black),
      cellPadding: const pw.EdgeInsets.all(6),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.center,
        4: pw.Alignment.centerRight,
      },
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
    );
  }
}
