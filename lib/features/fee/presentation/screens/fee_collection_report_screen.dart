import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/fee_provider.dart';
import '../utils/fee_report_pdf_generator.dart';

class FeeCollectionReportScreen extends StatefulWidget {
  const FeeCollectionReportScreen({super.key});

  @override
  State<FeeCollectionReportScreen> createState() => _FeeCollectionReportScreenState();
}

class _FeeCollectionReportScreenState extends State<FeeCollectionReportScreen> {
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  
  bool _isLoading = false;
  List<Map<String, dynamic>> _transactions = [];

  static const List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final provider = context.read<FeeProvider>();
    final data = await provider.getCollectionReport(_selectedMonth, _selectedYear);
    if (mounted) {
      setState(() {
        _transactions = data;
        _isLoading = false;
      });
    }
  }

  void _exportPdf() {
    FeeReportPdfGenerator.generateAndPrintReport(
      month: _selectedMonth,
      year: _selectedYear,
      transactions: _transactions,
    );
  }

  @override
  Widget build(BuildContext context) {
    double totalCollected = 0.0;
    for (var t in _transactions) {
      totalCollected += (t['transaction_amount'] as num).toDouble();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Monthly Collection Report', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF191A4E),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_transactions.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: _exportPdf,
              tooltip: 'Export PDF',
            ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          _buildSummary(totalCollected),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildTransactionList(),
          ),
        ],
      ),
      floatingActionButton: _transactions.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _exportPdf,
              icon: const Icon(Icons.download),
              label: const Text('Export PDF'),
              backgroundColor: const Color(0xFF2B9348),
            )
          : null,
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              decoration: InputDecoration(
                labelText: 'Month',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              initialValue: _selectedMonth,
              items: List.generate(12, (index) {
                return DropdownMenuItem(
                  value: index + 1,
                  child: Text(_months[index]),
                );
              }),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedMonth = val);
                  _fetchData();
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<int>(
              decoration: InputDecoration(
                labelText: 'Year',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              initialValue: _selectedYear,
              items: List.generate(5, (index) {
                int y = DateTime.now().year - 2 + index;
                return DropdownMenuItem(value: y, child: Text('$y'));
              }),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedYear = val);
                  _fetchData();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(double total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: const Color(0xFFE8F8EE),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Total Collected', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF191A4E))),
          Text('৳ ${total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF2B9348))),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    if (_transactions.isEmpty) {
      return const Center(child: Text('No collections for this month.'));
    }

    return ListView.separated(
      itemCount: _transactions.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final t = _transactions[index];
        final amount = (t['transaction_amount'] as num).toDouble();
        
        final dateStr = t['payment_date'] as String;
        final date = DateTime.tryParse(dateStr);
        final formattedDate = date != null ? DateFormat('dd MMM, hh:mm a').format(date) : dateStr;
        
        final feeMonth = t['fee_month'] as int;
        final feeYear = t['fee_year'] as int;
        final feeFor = '${_months[feeMonth - 1]} $feeYear';

        return ListTile(
          tileColor: Colors.white,
          title: Text(t['student_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t['batch_details_snapshot'] ?? '-', style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 14, color: Colors.black54),
                  const SizedBox(width: 4),
                  Text(formattedDate, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                  const SizedBox(width: 12),
                  const Icon(Icons.calendar_today, size: 14, color: Colors.black54),
                  const SizedBox(width: 4),
                  Text('Fee for: $feeFor', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                ],
              )
            ],
          ),
          trailing: Text(
            '৳${amount.toStringAsFixed(0)}',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2B9348), fontSize: 15),
          ),
        );
      },
    );
  }
}
