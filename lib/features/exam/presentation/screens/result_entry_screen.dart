import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/exam.dart';
import '../providers/exam_provider.dart';
import '../../../../core/widgets/common_widgets.dart';

class ResultEntryScreen extends StatefulWidget {
  final Exam exam;

  const ResultEntryScreen({super.key, required this.exam});

  @override
  State<ResultEntryScreen> createState() => _ResultEntryScreenState();
}

class _ResultEntryScreenState extends State<ResultEntryScreen> {
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
      appBar: AppBar(
        title: Text('${widget.exam.title} Results'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveResults,
          )
        ],
      ),
      body: Consumer<ExamProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.currentResults.isEmpty) {
            return const EmptyStateWidget(
              message: 'No students found in this batch.',
              icon: Icons.people_outline,
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.currentResults.length,
            itemBuilder: (context, index) {
              final result = provider.currentResults[index];
              return AppCard(
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        result.studentName ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Text('Absent: '),
                          Switch(
                            value: result.isAbsent,
                            onChanged: (val) {
                              provider.updateResultAbsent(result.studentId, val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        initialValue: result.obtainedMarks?.toString() ?? '',
                        decoration: const InputDecoration(labelText: 'Marks'),
                        keyboardType: TextInputType.number,
                        enabled: !result.isAbsent,
                        onChanged: (val) {
                          final marks = double.tryParse(val);
                          if (marks != null) {
                            provider.updateResultMarks(result.studentId, marks);
                          }
                        },
                      ),
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: _saveResults,
          child: const Text('Save All Results'),
        ),
      ),
    );
  }
}
