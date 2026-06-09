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
    });
  }

  void _onStudentSelected(Student? student) {
    setState(() {
      _selectedStudent = student;
    });
    if (student != null && student.id != null) {
      context.read<ExamProvider>().loadDetailedResultsForStudent(student.id!);
    }
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
          final allStudents = studentProvider.students;

          // Note: In a real app, we might want to filter students by enrollment in the selected batch.
          // For simplicity and since we don't have the enrollment map here easily, we'll just show all 
          // if no batch is selected. If a batch is selected, we ideally should filter, but the user
          // requested "always select present year, bellow left batch, right student... bellow search specific student"
          // We will use the searchable dropdown for student which covers the "search specific student" requirement.

          List<Student> filteredStudents = allStudents;
          // If we had a way to easily filter students by batch here we would, but without enrollment data loaded
          // efficiently, we'll just show all students and let the search handle it.

          return Column(
            children: [
              _buildFilterSection(batches, filteredStudents),
              if (_selectedStudent == null)
                const Expanded(
                  child: Center(
                    child: Text('Please select a student to view result analytics', style: TextStyle(color: Colors.black54, fontSize: 16)),
                  ),
                )
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
                        if (val != null) setState(() => _selectedYear = val);
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
                          onChanged: (val) {
                            setState(() => _selectedBatchId = val);
                          },
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
                    const Text('Search Student', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54)),
                    const SizedBox(height: 4),
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

  Widget _buildAnalyticsContent(ExamProvider examProvider) {
    // Filter results by selected year
    final yearResults = examProvider.detailedResults.where((r) => r.examDate.year == _selectedYear).toList();

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
              itemCount: yearResults.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _buildResultCard(yearResults[index]);
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
