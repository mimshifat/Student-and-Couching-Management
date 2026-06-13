import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/exam.dart';
import '../providers/exam_provider.dart';
import 'exam_form_screen.dart';

class ResultEntryScreen extends StatefulWidget {
  final Exam exam;

  const ResultEntryScreen({super.key, required this.exam});

  @override
  State<ResultEntryScreen> createState() => _ResultEntryScreenState();
}

class _ResultEntryScreenState extends State<ResultEntryScreen> {
  static const Color primaryNavy = Color(0xFF191A4E);

  // Persistent controllers keyed by studentId – avoids reset on rebuild
  final Map<int, TextEditingController> _marksControllers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExamProvider>().prepareResultsForExam(widget.exam);
    });
  }

  @override
  void dispose() {
    for (final ctrl in _marksControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  /// Returns (or creates) a controller for the given student.
  /// Only initialises the text once – subsequent rebuilds leave it untouched.
  TextEditingController _controllerFor(int studentId, double? obtainedMarks) {
    if (!_marksControllers.containsKey(studentId)) {
      _marksControllers[studentId] =
          TextEditingController(text: obtainedMarks?.toString() ?? '');
    }
    return _marksControllers[studentId]!;
  }

  void _saveResults() async {
    final provider = context.read<ExamProvider>();
    final success = await provider.saveResults(widget.exam.id!);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Results saved successfully')),
      );
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.errorMessage ?? 'An error occurred')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: primaryNavy,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Result Entry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white, size: 20),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ExamFormScreen(exam: widget.exam),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Compact Info Strip
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoCell(
                    icon: Icons.assignment_outlined,
                    label: 'Exam',
                    value: widget.exam.title,
                    flex: 3,
                  ),
                  _buildVerticalDivider(),
                  _buildInfoCell(
                    icon: Icons.group_outlined,
                    label: 'Batch',
                    value: widget.exam.batchName ?? 'Unknown',
                    flex: 3,
                  ),
                  _buildVerticalDivider(),
                  _buildInfoCell(
                    icon: Icons.calendar_today_outlined,
                    label: 'Date',
                    value: DateFormat('dd MMM yyyy').format(widget.exam.examDate),
                    flex: 2,
                  ),
                ],
              ),
            ),
          ),
          
          // Data Table
          Expanded(
            child: Consumer<ExamProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.currentResults.isEmpty) {
                  return const Center(
                    child: Text('No students found in this batch.', style: TextStyle(color: Colors.black54)),
                  );
                }

                return Container(
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      _buildTableHeader(),
                      const Divider(height: 1, color: Color(0xFFF0F0F0)),
                      Expanded(
                        child: ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: provider.currentResults.length,
                          separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF0F0F0)),
                          itemBuilder: (context, index) {
                            final result = provider.currentResults[index];
                            return RepaintBoundary(
                              child: _buildTableRow(result, provider),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Bottom Buttons
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFD0D5DD)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saveResults,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryNavy,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Save Result', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInfoCell({required IconData icon, required String label, required String value, int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 11, color: const Color(0xFF6B7280)),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
              softWrap: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      color: const Color(0xFFE5E7EB),
      margin: const EdgeInsets.symmetric(vertical: 4),
    );
  }

  Widget _buildTableHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('Student', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87))),
          Expanded(flex: 2, child: Center(child: Text('Marks (${widget.exam.totalMarks})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)))),
          Expanded(flex: 2, child: Center(child: Text('Status', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)))),
        ],
      ),
    );
  }

  Widget _buildTableRow(dynamic result, ExamProvider provider) {
    final ctrl = _controllerFor(result.studentId, result.obtainedMarks);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              result.studentName ?? 'Unknown',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87),
              softWrap: true,
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: SizedBox(
                width: 60,
                child: result.isAbsent
                  ? const Center(child: Text('-', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))
                  : TextField(
                      controller: ctrl,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                        border: InputBorder.none,
                      ),
                      onChanged: (val) {
                        final marks = double.tryParse(val);
                        if (marks != null) {
                          // Silent update — no notifyListeners() so keyboard stays open
                          provider.updateResultMarksSilent(result.studentId, marks);
                        }
                      },
                    ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: InkWell(
                onTap: () {
                  // Toggle absent status
                  provider.updateResultAbsent(result.studentId, !result.isAbsent);
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: result.isAbsent ? const Color(0xFFFFEBEE) : const Color(0xFFE8F8EE),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    result.isAbsent ? 'Absent' : 'Present',
                    style: TextStyle(
                      color: result.isAbsent ? const Color(0xFFC62828) : const Color(0xFF2B9348),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
