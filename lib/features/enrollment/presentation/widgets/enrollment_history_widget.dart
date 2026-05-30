import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/enrollment_provider.dart';
import '../screens/enrollment_screen.dart';
import '../../../batch/presentation/providers/batch_provider.dart';
import '../../../fee/presentation/providers/fee_provider.dart';
class EnrollmentHistoryWidget extends StatefulWidget {
  final int studentId;

  const EnrollmentHistoryWidget({super.key, required this.studentId});

  @override
  State<EnrollmentHistoryWidget> createState() => _EnrollmentHistoryWidgetState();
}

class _EnrollmentHistoryWidgetState extends State<EnrollmentHistoryWidget> {
  int _selectedTab = 0; // 0 for Active, 1 for Closed

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EnrollmentProvider>().loadStudentEnrollments(widget.studentId);
      context.read<BatchProvider>().loadBatches();
    });
  }

  void _leaveBatch(int enrollmentId, DateTime joinDate) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Batch'),
        content: const Text('Are you sure you want this student to leave this batch?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;

    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().isBefore(joinDate) ? joinDate : DateTime.now(),
      firstDate: joinDate,
      lastDate: DateTime(2100),
      helpText: 'Select Leave Date',
    );

    if (picked != null && mounted) {
      await context.read<EnrollmentProvider>().leaveBatch(enrollmentId, widget.studentId, picked);
      if (mounted) {
        context.read<FeeProvider>().loadStudentFeeData(widget.studentId);
        context.read<FeeProvider>().loadPendingFeeRecords();
      }
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
              if (ctx.mounted) {
                ctx.read<FeeProvider>().loadStudentFeeData(widget.studentId);
                ctx.read<FeeProvider>().loadPendingFeeRecords();
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String title, int index) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTab = index;
          });
        },
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withAlpha(13),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Text(
            title,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.black87 : Colors.black54,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Enrollments',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
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

            final filteredEnrollments = provider.historyEnrollments.where((e) {
              final isActive = e.leaveDate == null;
              if (_selectedTab == 0 && !isActive) return false;
              if (_selectedTab == 1 && isActive) return false;
              return true;
            }).toList();

            return Consumer<BatchProvider>(
              builder: (context, batchProvider, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          _buildTabButton('Active', 0),
                          _buildTabButton('Closed', 1),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (filteredEnrollments.isEmpty)
                      const Text('No records found for selected filter.', style: TextStyle(color: Colors.grey))
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAFAFA),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredEnrollments.length,
                          separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFEEEEEE)),
                          itemBuilder: (context, index) {
                            final e = filteredEnrollments[index];
                      final isActive = e.leaveDate == null;
                      final joinStr = DateFormat('dd MMM yyyy').format(e.joinDate);
                      
                      String titleStr = e.batchName ?? 'Unknown Batch';
                      if (e.studentClass != null && e.studentClass!.isNotEmpty) {
                        titleStr += ' (${e.studentClass})';
                      }
                      
                      String scheduleStr = '';
                      if (e.batchScheduleDaysSnapshot != null && e.batchScheduleDaysSnapshot!.isNotEmpty && e.batchTimeSlotSnapshot != null) {
                        scheduleStr = '${e.batchScheduleDaysSnapshot} ${e.batchTimeSlotSnapshot}';
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
                                color: const Color(0xFFEEF0FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.class_outlined, color: Color(0xFF3B41C5), size: 22),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    titleStr,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    scheduleStr.isNotEmpty ? 'Join: $joinStr • $scheduleStr' : 'Join: $joinStr',
                                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                                  ),
                                  if (e.feeOverride != null && e.feeOverride! >= 0) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Custom Fee: ${e.feeOverride} ৳',
                                      style: const TextStyle(color: Colors.black54, fontSize: 12),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isActive ? const Color(0xFFE8F8EE) : const Color(0xFFF5F5F5),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isActive ? 'Active' : 'Past',
                                    style: TextStyle(
                                      color: isActive ? const Color(0xFF2B9348) : Colors.black54,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                if (isActive) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      InkWell(
                                        onTap: () => _editFee(e.id!, e.feeOverride),
                                        child: const Padding(
                                          padding: EdgeInsets.all(4.0),
                                          child: Icon(Icons.edit, size: 16, color: Colors.blue),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () => _leaveBatch(e.id!, e.joinDate),
                                        child: const Padding(
                                          padding: EdgeInsets.all(4.0),
                                          child: Icon(Icons.exit_to_app, size: 16, color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
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
