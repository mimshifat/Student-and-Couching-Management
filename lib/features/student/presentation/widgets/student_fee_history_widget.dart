import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../fee/presentation/providers/fee_provider.dart';
import '../../../fee/presentation/screens/fee_payment_screen.dart';
import '../providers/student_provider.dart';

class StudentFeeHistoryWidget extends StatefulWidget {
  final int studentId;

  const StudentFeeHistoryWidget({super.key, required this.studentId});

  @override
  State<StudentFeeHistoryWidget> createState() => _StudentFeeHistoryWidgetState();
}

class _StudentFeeHistoryWidgetState extends State<StudentFeeHistoryWidget> {
  int? _selectedYear;
  int _selectedTab = 0; // 0 for Due, 1 for Paid

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FeeProvider>().loadStudentFeeData(widget.studentId);
    });
  }

  Widget _buildTabButton(String title, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
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

            final allRecords = provider.studentFeeRecords;
            if (allRecords.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No fee records found for this student.'),
              );
            }

            final Set<int> yearsSet = allRecords.map((e) => e.year).toSet();
            final List<int> availableYears = yearsSet.toList()..sort((a, b) => b.compareTo(a));

            final filteredRecords = allRecords.where((r) {
              if (_selectedYear != null && r.year != _selectedYear) return false;
              final isPaid = r.paidAmount >= r.totalAmount;
              if (_selectedTab == 0 && isPaid) return false; // Due Tab
              if (_selectedTab == 1 && !isPaid) return false; // Paid Tab
              return true;
            }).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildTabButton('Due', 0),
                          _buildTabButton('Paid', 1),
                        ],
                      ),
                    ),
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          value: _selectedYear,
                          hint: const Text('All Years'),
                          icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('All Years'),
                            ),
                            ...availableYears.map((year) => DropdownMenuItem<int?>(
                              value: year,
                              child: Text(year.toString()),
                            ))
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedYear = val;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                if (filteredRecords.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No records found for selected filters.'),
                  )
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
                      itemCount: filteredRecords.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFEEEEEE)),
                      itemBuilder: (context, index) {
                        final record = filteredRecords[index];
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
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
                            if (!isPaid) ...[
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () {
                                  final student = context.read<StudentProvider>().students.firstWhere((s) => s.id == widget.studentId);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => FeePaymentScreen(
                                        studentId: widget.studentId,
                                        studentName: student.name,
                                        feeRecord: record,
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE3F2FD),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.payment, size: 14, color: Colors.blue),
                                      SizedBox(width: 4),
                                      Text('Pay', style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
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
          },
        ),
      ],
    );
  }
}
