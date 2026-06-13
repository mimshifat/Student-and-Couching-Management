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
  bool _isSaving = false;

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

  /// Formats a double mark for display: whole numbers show as "85" not "85.0".
  String _formatMark(double? mark) {
    if (mark == null) return '';
    return mark == mark.truncateToDouble()
        ? mark.toInt().toString()
        : mark.toString();
  }

  /// Returns (or creates) a controller for the given student.
  /// Syncs text using double comparison so that typing "8" doesn't get
  /// overwritten by "8.0" when a sibling rebuild (e.g. absent toggle) fires.
  TextEditingController _controllerFor(int studentId, double? obtainedMarks) {
    final expectedText = _formatMark(obtainedMarks);

    if (!_marksControllers.containsKey(studentId)) {
      _marksControllers[studentId] =
          TextEditingController(text: expectedText);
    } else {
      final ctrl = _marksControllers[studentId]!;
      // Compare as doubles, not strings — prevents "8" vs "8.0" false mismatch
      // that would overwrite the field and jump the cursor mid-typing.
      final ctrlValue = double.tryParse(ctrl.text);
      if (ctrlValue != obtainedMarks) {
        ctrl.text = expectedText;
      }
    }
    return _marksControllers[studentId]!;
  }

  /// Flushes every TextField value into the provider right before saving.
  /// This is the authoritative sync — we read what the user actually sees
  /// on screen, not what onChanged may or may not have captured.
  /// Skips absent students so their isAbsent flag is never overridden.
  void _commitControllerValues(ExamProvider provider) {
    for (final entry in _marksControllers.entries) {
      final studentId = entry.key;
      // Never override an absent student's status with stale controller text.
      final result = provider.currentResults
          .where((r) => r.studentId == studentId)
          .firstOrNull;
      if (result == null || result.isAbsent) continue;

      final text = entry.value.text.trim();
      if (text.isEmpty) {
        // User cleared the field → explicitly set marks to null
        provider.clearResultMarksSilent(studentId);
      } else {
        final marks = double.tryParse(text);
        if (marks != null && marks <= widget.exam.totalMarks) {
          provider.updateResultMarksSilent(studentId, marks);
        }
      }
    }
  }

  void _saveResults() async {
    if (_isSaving) return; // Prevent double-tap
    setState(() => _isSaving = true);

    final provider = context.read<ExamProvider>();

    try {
      // Always flush controller text → provider before saving.
      _commitControllerValues(provider);

      final success = await provider.saveResults(widget.exam.id!);

      if (!mounted) return;
      setState(() => _isSaving = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Results saved successfully')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.errorMessage ?? 'An error occurred')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving results: $e')),
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
                    value: widget.exam.displayBatchName,
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
                      onPressed: _isSaving ? null : _saveResults,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryNavy,
                        disabledBackgroundColor: primaryNavy.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2,
                              ),
                            )
                          : const Text('Save Result', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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
          Expanded(flex: 2, child: Center(child: Text('Marks (${_formatMark(widget.exam.totalMarks)})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)))),
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
                        final text = val.trim();
                        if (text.isEmpty) {
                          // User cleared the field — set marks to null
                          provider.clearResultMarksSilent(result.studentId);
                          return;
                        }
                        final marks = double.tryParse(text);
                        if (marks == null) return;
                        // Validate against totalMarks
                        if (marks > widget.exam.totalMarks) {
                          ScaffoldMessenger.of(context)
                            ..clearSnackBars()
                            ..showSnackBar(SnackBar(
                              content: Text(
                                'Marks cannot exceed ${_formatMark(widget.exam.totalMarks)}',
                              ),
                              backgroundColor: Colors.red.shade700,
                              duration: const Duration(seconds: 2),
                            ));
                          return;
                        }
                        // Silent update — no notifyListeners() so keyboard stays open
                        provider.updateResultMarksSilent(result.studentId, marks);
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
                  final goingAbsent = !result.isAbsent;
                  provider.updateResultAbsent(result.studentId, goingAbsent);
                  // Clear controller in BOTH directions:
                  //  → going absent: old marks text must not survive into _commitControllerValues
                  //  → going present: start with blank so user enters fresh marks
                  _marksControllers[result.studentId]?.text = '';
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
