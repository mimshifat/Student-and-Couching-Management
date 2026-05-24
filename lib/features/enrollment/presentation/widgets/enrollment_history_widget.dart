import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/common_widgets.dart';
import '../providers/enrollment_provider.dart';
import '../screens/enrollment_screen.dart';

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

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: provider.historyEnrollments.length,
                itemBuilder: (context, index) {
                  final e = provider.historyEnrollments[index];
                  final isActive = e.leaveDate == null;
                  final joinStr = DateFormat('dd MMM yyyy').format(e.joinDate);
                  final leaveStr = e.leaveDate != null ? DateFormat('dd MMM yyyy').format(e.leaveDate!) : 'Present';

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(e.batchName ?? 'Unknown Batch', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Joined: $joinStr\nLeft: $leaveStr'),
                    trailing: isActive
                        ? OutlinedButton(
                            onPressed: () => _leaveBatch(e.id!),
                            child: const Text('Leave'),
                          )
                        : const Text('Past', style: TextStyle(color: Colors.grey)),
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
