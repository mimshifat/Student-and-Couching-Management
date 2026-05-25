import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/common_widgets.dart';
import '../../../fee/presentation/providers/fee_provider.dart';

class StudentFeeHistoryWidget extends StatefulWidget {
  final int studentId;

  const StudentFeeHistoryWidget({super.key, required this.studentId});

  @override
  State<StudentFeeHistoryWidget> createState() => _StudentFeeHistoryWidgetState();
}

class _StudentFeeHistoryWidgetState extends State<StudentFeeHistoryWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FeeProvider>().loadStudentFeeData(widget.studentId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Fee History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  context.read<FeeProvider>().loadStudentFeeData(widget.studentId);
                },
              )
            ],
          ),
          const SizedBox(height: 16),
          Consumer<FeeProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (provider.errorMessage != null) {
                return Center(child: Text('Error: ${provider.errorMessage}'));
              }

              final records = provider.studentFeeRecords;
              if (records.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No fee records found for this student.'),
                );
              }

              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: records.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFEEEEEE)),
                  itemBuilder: (context, index) {
                    final record = records[index];
                    final isPaid = record.paidAmount >= record.totalAmount;

                    // Format month (e.g. "April")
                    final String monthName = DateFormat('MMMM').format(DateTime(record.year, record.month));
                    final String yearMonthStr = '$monthName ${record.year}';

                    // Parse batchDetailsSnapshot
                    String batchName = 'General Fee';
                    if (record.batchDetailsSnapshot != null && record.batchDetailsSnapshot!.isNotEmpty) {
                      batchName = record.batchDetailsSnapshot!;
                      if (batchName.contains('(')) {
                        batchName = batchName.split('(').first.trim();
                      }
                    } else if (record.studentClass != null && record.studentClass!.isNotEmpty) {
                      batchName = 'Class ${record.studentClass}';
                    }
                    
                    String scheduleStr = '';
                    if (record.batchDetailsSnapshot != null && record.batchDetailsSnapshot!.contains('(')) {
                      int start = record.batchDetailsSnapshot!.indexOf('(') + 1;
                      int end = record.batchDetailsSnapshot!.indexOf(')');
                      if (end > start) {
                        scheduleStr = record.batchDetailsSnapshot!.substring(start, end);
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.receipt_long_outlined, color: Color(0xFF2E7D32), size: 22),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  batchName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  scheduleStr.isNotEmpty ? '$yearMonthStr • $scheduleStr' : yearMonthStr,
                                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Total: ৳${record.totalAmount.toStringAsFixed(0)} | Paid: ৳${record.paidAmount.toStringAsFixed(0)}',
                                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isPaid ? const Color(0xFFE8F8EE) : const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isPaid ? 'Paid' : 'Due: ৳${(record.totalAmount - record.paidAmount).toStringAsFixed(0)}',
                              style: TextStyle(
                                color: isPaid ? const Color(0xFF2B9348) : const Color(0xFFC62828),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
