import 'package:flutter/material.dart';

import '../../../../core/widgets/common_widgets.dart';
import '../../../exam/presentation/widgets/performance_chart.dart';
import '../../../exam/domain/entities/result.dart';
import '../../../exam/data/repositories/exam_repository_impl.dart';

class StudentPerformanceWidget extends StatefulWidget {
  final int studentId;

  const StudentPerformanceWidget({super.key, required this.studentId});

  @override
  State<StudentPerformanceWidget> createState() => _StudentPerformanceWidgetState();
}

class _StudentPerformanceWidgetState extends State<StudentPerformanceWidget> {
  bool _isLoading = true;
  List<ExamResult> _results = [];

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    final repo = ExamRepositoryImpl();
    final results = await repo.getResultsForStudent(widget.studentId);
    if (mounted) {
      setState(() {
        _results = results;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AppCard(child: Center(child: CircularProgressIndicator()));
    }

    return PerformanceChart(results: _results);
  }
}
