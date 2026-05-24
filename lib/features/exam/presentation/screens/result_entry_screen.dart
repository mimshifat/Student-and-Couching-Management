import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/exam.dart';
import '../providers/exam_provider.dart';

class ResultEntryScreen extends StatefulWidget {
  final Exam exam;

  const ResultEntryScreen({super.key, required this.exam});

  @override
  State<ResultEntryScreen> createState() => _ResultEntryScreenState();
}

class _ResultEntryScreenState extends State<ResultEntryScreen> {
  static const Color primaryNavy = Color(0xFF191A4E);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExamProvider>().prepareResultsForExam(widget.exam);
    });
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
              // Edit exam logic (if we want to wire it up later)
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Header Fields
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildHeaderField('Exam', widget.exam.title, isDropdown: true),
                const SizedBox(height: 12),
                _buildHeaderField('Batch', widget.exam.batchName ?? 'Unknown', isDropdown: true),
                const SizedBox(height: 12),
                _buildHeaderField('Date', DateFormat('dd MMM yyyy').format(widget.exam.examDate)),
              ],
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
                            return _buildTableRow(result, provider);
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

  Widget _buildHeaderField(String label, String value, {bool isDropdown = false}) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(value, style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500)),
                if (isDropdown) const Icon(Icons.keyboard_arrow_down, color: Colors.black38, size: 20),
              ],
            ),
          ),
        ),
      ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              result.studentName ?? 'Unknown',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: SizedBox(
                width: 60,
                child: result.isAbsent 
                  ? const Center(child: Text('-', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))
                  : TextFormField(
                      initialValue: result.obtainedMarks?.toString() ?? '',
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
                          provider.updateResultMarks(result.studentId, marks);
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
