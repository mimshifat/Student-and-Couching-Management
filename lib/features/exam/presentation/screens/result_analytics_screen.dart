import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/exam_provider.dart';
import '../../../student/presentation/providers/student_provider.dart';
import '../../../batch/presentation/providers/batch_provider.dart';
import '../../../student/domain/entities/student.dart';
import '../../domain/entities/detailed_result.dart';
import '../../../../core/widgets/searchable_dropdown.dart';
import '../../../../core/widgets/app_drawer.dart';

class ResultAnalyticsScreen extends StatefulWidget {
  const ResultAnalyticsScreen({super.key});

  @override
  State<ResultAnalyticsScreen> createState() => _ResultAnalyticsScreenState();
}

class _ResultAnalyticsScreenState extends State<ResultAnalyticsScreen> {
  late int _selectedYear;
  int? _selectedBatchId;
  Student? _selectedStudent;

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudentProvider>().loadStudents();
      context.read<BatchProvider>().loadBatches();
      // Use efficient aggregate query instead of loading all raw rows
      context.read<ExamProvider>().loadBatchSummaries(null, _selectedYear);
    });
  }

  void _onStudentSelected(Student? student) {
    setState(() {
      _selectedStudent = student;
    });
    if (student != null && student.id != null) {
      // Use year-filtered DB query — no Dart .where() loop
      context.read<ExamProvider>().loadDetailedResultsByYear(student.id!, _selectedYear);
    }
  }

  void _onYearChanged(int year) {
    setState(() => _selectedYear = year);
    // Reload data for the new year at DB level
    context.read<ExamProvider>().loadBatchSummaries(_selectedBatchId, year);
    if (_selectedStudent?.id != null) {
      context.read<ExamProvider>().loadDetailedResultsByYear(_selectedStudent!.id!, year);
    }
  }

  void _onBatchChanged(int? batchId) {
    setState(() {
      _selectedBatchId = batchId;
      _selectedStudent = null;
    });
    if (batchId == null) {
      context.read<StudentProvider>().loadStudents();
    } else {
      context.read<StudentProvider>().loadStudentsByBatch(batchId);
    }
    // Use efficient aggregate query
    context.read<ExamProvider>().loadBatchSummaries(batchId, _selectedYear);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: const Color(0xFF191A4E),
        elevation: 0,
        centerTitle: true,
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => Scaffold.of(context).openDrawer(),
            );
          },
        ),
        title: const Text('Result Analytics', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Consumer3<StudentProvider, BatchProvider, ExamProvider>(
        builder: (context, studentProvider, batchProvider, examProvider, child) {
          final batches = batchProvider.batches;
          // Students are already filtered by batch (or all) via the provider
          final filteredStudents = studentProvider.students;

          return Column(
            children: [
              _buildFilterSection(batches, filteredStudents),
              if (_selectedStudent == null)
                examProvider.isLoading
                  ? const Expanded(child: Center(child: CircularProgressIndicator()))
                  : _buildBatchSummary(examProvider)
              else if (examProvider.isLoading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else
                _buildAnalyticsContent(examProvider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterSection(List<dynamic> batches, List<Student> students) {
    final currentYear = DateTime.now().year;
    final years = List.generate(10, (index) => currentYear - 5 + index).reversed.toList();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Year Selection
          Row(
            children: [
              const Icon(Icons.calendar_month, color: Color(0xFF191A4E), size: 20),
              const SizedBox(width: 8),
              const Text('Academic Year:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4F8),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: _selectedYear,
                      items: years.map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
                      onChanged: (val) {
                        if (val != null) _onYearChanged(val);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Batch and Student Selection
          Row(
            children: [
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Batch', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54)),
                    const SizedBox(height: 4),
                    Container(
                      height: 45,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          isExpanded: true,
                          value: _selectedBatchId,
                          hint: const Text('All Batches', style: TextStyle(fontSize: 13)),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All Batches', style: TextStyle(fontSize: 13))),
                            ...batches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name, style: const TextStyle(fontSize: 13)))),
                          ],
                          onChanged: _onBatchChanged,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SearchableDropdown<Student, Student>(
                      label: '', // Hidden label
                      icon: Icons.person_search,
                      value: _selectedStudent,
                      items: students,
                      itemLabel: (s) => s.name,
                      itemSearchString: (s) => '${s.name} ${s.phone ?? ''}',
                      itemValue: (s) => s,
                      hint: 'Select Student',
                      onChanged: _onStudentSelected,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBatchSummary(ExamProvider examProvider) {
    final summaries = examProvider.batchSummaries;

    if (summaries.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bar_chart_outlined, size: 72, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'No exam results for $_selectedYear',
                style: const TextStyle(color: Colors.black45, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add exam results to see analytics',
                style: TextStyle(color: Colors.black38, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    // Overall stats computed from already-aggregated BatchSummary objects — O(n batches) not O(n results)
    final totalResults = summaries.fold(0, (s, b) => s + b.totalResults);
    final totalAbsents = summaries.fold(0, (s, b) => s + b.absentCount);
    final totalObtained = summaries.fold(0.0, (s, b) => s + b.totalObtained);
    final totalAvailable = summaries.fold(0.0, (s, b) => s + b.totalAvailable);
    final overallAvg = totalAvailable > 0 ? (totalObtained / totalAvailable) * 100 : 0.0;

    final bannerLabel = _selectedBatchId == null
        ? 'All Batches — $_selectedYear'
        : '${summaries.first.batchName} — $_selectedYear';

    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overall Summary Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF191A4E), Color(0xFF2D3080)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF191A4E).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.analytics, color: Colors.white70, size: 18),
                      const SizedBox(width: 8),
                      Text(bannerLabel, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildBannerStat('Total Results', totalResults.toString()),
                      _buildBannerStat('Avg Score', '${overallAvg.toStringAsFixed(1)}%'),
                      _buildBannerStat('Absent', totalAbsents.toString()),
                      _buildBannerStat('Batches', summaries.length.toString()),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('Batch Performance', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 12),
            // Per-batch cards — one item per BatchSummary (not per raw result row)
            ...summaries.map((b) {
              final bColor = b.avgPercent >= 70
                  ? const Color(0xFF2B9348)
                  : b.avgPercent >= 40
                      ? const Color(0xFFF57C00)
                      : const Color(0xFFD32F2F);

              return RepaintBoundary(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F4F8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.group, color: Color(0xFF191A4E), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(b.batchName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                                Text('${b.uniqueStudents} students • ${b.totalResults} results', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: bColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${b.avgPercent.toStringAsFixed(1)}%',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: bColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (b.avgPercent / 100).clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: Colors.grey.shade100,
                          valueColor: AlwaysStoppedAnimation<Color>(bColor),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildBatchStatPill(Icons.assignment_turned_in, '${b.totalResults} Results', const Color(0xFF1A73E8)),
                          const SizedBox(width: 8),
                          _buildBatchStatPill(Icons.show_chart, '${b.totalObtained.toStringAsFixed(0)}/${b.totalAvailable.toStringAsFixed(0)} pts', const Color(0xFF2B9348)),
                          const SizedBox(width: 8),
                          _buildBatchStatPill(Icons.person_off, '${b.absentCount} Absent', const Color(0xFFD32F2F)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    );
  }

  Widget _buildBatchStatPill(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildAnalyticsContent(ExamProvider examProvider) {
    // Results are already filtered by year at DB level — no in-memory .where() needed
    final yearResults = examProvider.yearFilteredResults;

    if (yearResults.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.analytics_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text('No exams found for $_selectedYear', style: const TextStyle(color: Colors.black54, fontSize: 16)),
            ],
          ),
        ),
      );
    }

    // Calculate Summary Stats
    int totalExams = yearResults.length;
    int absents = 0;
    double totalMarksAvailable = 0;
    double totalMarksObtained = 0;
    double maxPercentage = 0;
    double minPercentage = 100;
    bool hasValidMarks = false;

    for (var r in yearResults) {
      if (r.isAbsent || r.obtainedMarks == null) {
        absents++;
      } else {
        totalMarksAvailable += r.totalMarks;
        totalMarksObtained += r.obtainedMarks!;
        final pct = (r.obtainedMarks! / r.totalMarks) * 100;
        if (pct > maxPercentage) maxPercentage = pct;
        if (pct < minPercentage) minPercentage = pct;
        hasValidMarks = true;
      }
    }

    if (!hasValidMarks) {
      minPercentage = 0;
      maxPercentage = 0;
    }

    final overallAverage = totalMarksAvailable > 0 ? (totalMarksObtained / totalMarksAvailable) * 100 : 0.0;

    return Expanded(
      child: Column(
        children: [
          // Student Header Info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFFE8F0FE),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF191A4E),
                  radius: 20,
                  child: Text(_selectedStudent!.name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_selectedStudent!.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF191A4E))),
                      if (_selectedStudent!.className != null)
                        Text('Class: ${_selectedStudent!.className}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFF191A4E), borderRadius: BorderRadius.circular(12)),
                  child: Text('Year $_selectedYear', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ),
          
          // Summary Cards
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(child: _buildStatCard('Exams', totalExams.toString(), Icons.assignment, const Color(0xFF1A73E8))),
                const SizedBox(width: 8),
                Expanded(child: _buildStatCard('Average', '${overallAverage.toStringAsFixed(1)}%', Icons.show_chart, const Color(0xFF2B9348))),
                const SizedBox(width: 8),
                Expanded(child: _buildStatCard('Highest', '${maxPercentage.toStringAsFixed(0)}%', Icons.arrow_upward, const Color(0xFFF57C00))),
                const SizedBox(width: 8),
                Expanded(child: _buildStatCard('Absent', absents.toString(), Icons.person_off, const Color(0xFFD32F2F))),
              ],
            ),
          ),

          // Results List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: false, // We add our own RepaintBoundary
              itemCount: yearResults.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return RepaintBoundary(
                  child: _buildResultCard(yearResults[index]),
                );
              },
            ),
          ),

          // Grand Total Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), offset: const Offset(0, -4), blurRadius: 8)],
            ),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Overall Performance', style: TextStyle(color: Colors.black54, fontSize: 12)),
                      Text(
                        '${totalMarksObtained.toStringAsFixed(1)} / ${totalMarksAvailable.toStringAsFixed(1)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF191A4E)),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: overallAverage >= 40 ? const Color(0xFFE8F8EE) : const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          overallAverage >= 40 ? Icons.check_circle : Icons.warning,
                          color: overallAverage >= 40 ? const Color(0xFF2B9348) : const Color(0xFFD32F2F),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${overallAverage.toStringAsFixed(2)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: overallAverage >= 40 ? const Color(0xFF2B9348) : const Color(0xFFD32F2F),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 11, color: Colors.black54), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildResultCard(DetailedResult result) {
    final dateStr = DateFormat('dd MMM yyyy').format(result.examDate);
    final isAbsent = result.isAbsent || result.obtainedMarks == null;
    final percentage = result.percentage;
    
    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (isAbsent) {
      statusColor = const Color(0xFFD32F2F);
      statusIcon = Icons.cancel;
      statusText = 'Absent';
    } else {
      if (percentage! >= 80) {
        statusColor = const Color(0xFF2B9348); // Green
        statusIcon = Icons.verified;
      } else if (percentage >= 40) {
        statusColor = const Color(0xFFF57C00); // Orange
        statusIcon = Icons.check_circle;
      } else {
        statusColor = const Color(0xFFD32F2F); // Red
        statusIcon = Icons.warning;
      }
      statusText = '${result.obtainedMarks?.toStringAsFixed(1)} / ${result.totalMarks.toStringAsFixed(0)}';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4F8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.assignment, color: Color(0xFF191A4E), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.examTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                const SizedBox(height: 4),
                Text('${result.batchName ?? 'Unknown Batch'} • ${result.examType}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 4),
                Text(dateStr, style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  Text(statusText, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: statusColor)),
                  const SizedBox(width: 4),
                  Icon(statusIcon, color: statusColor, size: 16),
                ],
              ),
              if (!isAbsent) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text('${percentage!.toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: statusColor)),
                ),
              ]
            ],
          ),
        ],
      ),
    );
  }
}
