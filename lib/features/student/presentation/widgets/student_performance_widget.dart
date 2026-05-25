import 'package:flutter/material.dart';

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
  int? _selectedYear;
  int? _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
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
      return const Center(child: CircularProgressIndicator());
    }

    final Set<int> yearsSet = _results.map((e) => e.createdAt.year).toSet();
    if (_selectedYear != null) {
      yearsSet.add(_selectedYear!);
    }
    final List<int> availableYears = yearsSet.toList()..sort((a, b) => b.compareTo(a));

    final filteredResults = _results.where((r) {
      if (_selectedYear != null && r.createdAt.year != _selectedYear) return false;
      if (_selectedMonth != null && r.createdAt.month != _selectedMonth) return false;
      return true;
    }).toList();

    final List<String> months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
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
                  value: _selectedMonth,
                  hint: const Text('All Months'),
                  icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('All Months'),
                    ),
                    ...List.generate(12, (index) {
                      return DropdownMenuItem<int?>(
                        value: index + 1,
                        child: Text(months[index]),
                      );
                    })
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedMonth = val;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
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
        PerformanceChart(results: filteredResults),
      ],
    );
  }
}
