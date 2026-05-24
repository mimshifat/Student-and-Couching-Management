import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
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

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: records.length,
                itemBuilder: (context, index) {
                  final record = records[index];
                  final isPaid = record.paidAmount >= record.totalAmount;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${record.month} ${record.year}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Total: ৳${record.totalAmount.toStringAsFixed(0)} | Paid: ৳${record.paidAmount.toStringAsFixed(0)}'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPaid ? Colors.green.withValues(alpha: 0.1) : AppTheme.errorColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isPaid ? 'PAID' : 'DUE: ৳${(record.totalAmount - record.paidAmount).toStringAsFixed(0)}',
                        style: TextStyle(
                          color: isPaid ? Colors.green : AppTheme.errorColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
