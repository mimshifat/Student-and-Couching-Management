import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/common_widgets.dart';
import '../providers/enrollment_provider.dart';
import '../screens/enrollment_screen.dart';
import '../../../batch/presentation/providers/batch_provider.dart';

class EnrollmentHistoryWidget extends StatefulWidget {
  final int studentId;

  const EnrollmentHistoryWidget({super.key, required this.studentId});

  @override
  State<EnrollmentHistoryWidget> createState() => _EnrollmentHistoryWidgetState();
}

class _EnrollmentHistoryWidgetState extends State<EnrollmentHistoryWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EnrollmentProvider>().loadStudentEnrollments(widget.studentId);
      context.read<BatchProvider>().loadBatches();
    });
  }

  void _leaveBatch(int enrollmentId) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Select Leave Date',
    );

    if (picked != null && mounted) {
      await context.read<EnrollmentProvider>().leaveBatch(enrollmentId, widget.studentId, picked);
    }
  }

  void _editFee(int enrollmentId, double? currentFee) {
    final ctrl = TextEditingController(text: currentFee?.toString() ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Custom Fee'),
        content: TextFormField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'New Monthly Fee',
            hintText: 'Leave empty for default',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final val = ctrl.text.trim();
              final double? newFee = val.isEmpty ? null : double.tryParse(val);
              await context.read<EnrollmentProvider>().updateFeeOverride(enrollmentId, widget.studentId, newFee);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
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
              const Text(
                'Enrollment History',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Enroll'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EnrollmentScreen(studentId: widget.studentId),
                    ),
                  );
                },
              )
            ],
          ),
          const SizedBox(height: 8),
          Consumer<EnrollmentProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (provider.historyEnrollments.isEmpty) {
                return const Text('No enrollment records found.', style: TextStyle(color: Colors.grey));
              }

              return Consumer<BatchProvider>(
                builder: (context, batchProvider, _) {
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: provider.historyEnrollments.length,
                    itemBuilder: (context, index) {
                      final e = provider.historyEnrollments[index];
                      final isActive = e.leaveDate == null;
                      final joinStr = DateFormat('dd MMM yyyy').format(e.joinDate);
                      final leaveStr = e.leaveDate != null ? DateFormat('dd MMM yyyy').format(e.leaveDate!) : 'Present';
                      
                      double defaultFee = 0;
                      try {
                        final batch = batchProvider.batches.firstWhere((b) => b.id == e.batchId);
                        defaultFee = batch.monthlyFee;
                      } catch (_) {}

                      String feeText = 'Fee: $defaultFee ৳';
                      if (e.feeOverride != null && e.feeOverride! >= 0) {
                        feeText = 'Regular Fee: $defaultFee ৳ | Custom Fee: ${e.feeOverride} ৳';
                      }

                      String titleStr = e.batchName ?? 'Unknown Batch';
                      if (e.studentClass != null && e.studentClass!.isNotEmpty) {
                        titleStr += ' (${e.studentClass})';
                      }
                      
                      String scheduleStr = '';
                      if (e.batchScheduleDaysSnapshot != null && e.batchTimeSlotSnapshot != null) {
                        scheduleStr = 'Schedule: ${e.batchScheduleDaysSnapshot} | ${e.batchTimeSlotSnapshot}\n';
                      }

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(titleStr, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('Joined: $joinStr\nLeft: $leaveStr\n$scheduleStr$feeText'),
                        isThreeLine: true,
                        trailing: isActive
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                    onPressed: () => _editFee(e.id!, e.feeOverride),
                                    tooltip: 'Edit Custom Fee',
                                  ),
                                  OutlinedButton(
                                    onPressed: () => _leaveBatch(e.id!),
                                    child: const Text('Leave'),
                                  ),
                                ],
                              )
                            : const Text('Past', style: TextStyle(color: Colors.grey)),
                      );
                    },
                  );
                }
              );
            },
          ),
        ],
      ),
    );
  }
}
