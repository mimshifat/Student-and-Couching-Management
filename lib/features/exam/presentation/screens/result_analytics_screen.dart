import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/exam_provider.dart';
import '../../../student/presentation/providers/student_provider.dart';
import '../../../batch/presentation/providers/batch_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../student/domain/entities/student.dart';
import '../../domain/entities/detailed_result.dart';
import '../../../../core/widgets/searchable_dropdown.dart';
import '../../../../core/widgets/app_drawer.dart';
import '../../../../core/utils/number_format_extension.dart';

import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../../../../core/utils/pdf_report_service.dart';

class ResultAnalyticsScreen extends StatefulWidget {
  const ResultAnalyticsScreen({super.key});

  @override
  State<ResultAnalyticsScreen> createState() => _ResultAnalyticsScreenState();
}

class _ResultAnalyticsScreenState extends State<ResultAnalyticsScreen> {
  late int _selectedYear;
  int? _startMonth = 1;
  int? _endMonth = DateTime.now().month;
  
  int? _selectedBatchId;
  Student? _selectedStudent;

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudentProvider>().loadStudents();
      context.read<BatchProvider>().loadBatches();
      _loadData();
    });
  }

  void _loadData() {
    context.read<ExamProvider>().loadBatchSummaries(_selectedBatchId, year: _selectedYear, startMonth: _startMonth, endMonth: _endMonth);
    if (_selectedStudent?.id != null) {
      context.read<ExamProvider>().loadDetailedResultsFiltered(_selectedStudent!.id!, year: _selectedYear, startMonth: _startMonth, endMonth: _endMonth);
    }
  }

  String get _currentPeriodLabel {
    if (_startMonth == null && _endMonth == null) {
      return _selectedYear.toString();
    } else if (_startMonth == null && _endMonth != null) {
      return '${DateFormat('MMM').format(DateTime(2000, _endMonth!))} $_selectedYear';
    } else if (_endMonth == null || _startMonth == _endMonth) {
      return '${DateFormat('MMM').format(DateTime(2000, _startMonth!))} $_selectedYear';
    } else {
      return '${DateFormat('MMM').format(DateTime(2000, _startMonth!))} - ${DateFormat('MMM').format(DateTime(2000, _endMonth!))} $_selectedYear';
    }
  }

  void _onStudentSelected(Student? student) {
    setState(() {
      _selectedStudent = student;
    });
    if (student != null) {
      _loadData();
    }
  }

  void _onStartMonthChanged(int? month) {
    setState(() {
      _startMonth = month;
      if (month != null && _endMonth != null && _endMonth! < month) {
        _endMonth = month;
      }
    });
    _loadData();
  }

  void _onEndMonthChanged(int? month) {
    setState(() {
      _endMonth = month;
      if (month != null && _startMonth != null && _startMonth! > month) {
        _startMonth = month;
      }
    });
    _loadData();
  }

  void _onBatchChanged(int? batchId) {
    setState(() {
      _selectedBatchId = batchId;
      _selectedStudent = null;
    });
    if (batchId == null) {
      context.read<StudentProvider>().loadStudents();
    } else {
      context.read<StudentProvider>().loadStudentsEverEnrolledInBatch(batchId);
    }
    _loadData();
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
        actions: [
          IconButton(
            icon: const Icon(Icons.home, color: Colors.white),
            onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
            tooltip: 'Home',
          ),
        ],
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

  Widget _buildDropdown<T>({required T value, required List<DropdownMenuItem<T>> items, required void Function(T?) onChanged}) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildFilterSection(List<dynamic> batches, List<Student> students) {
    final currentYear = DateTime.now().year;
    final years = List.generate(10, (index) => currentYear - 5 + index).reversed.toList();
    final months = List.generate(12, (index) => index + 1);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time Filters
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildDropdown<int>(
                  value: _selectedYear,
                  items: years.map((y) => DropdownMenuItem(value: y, child: Text(y.toString(), style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedYear = val);
                      _loadData();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: _buildDropdown<int?>(
                  value: _startMonth,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Months', style: TextStyle(fontSize: 13))),
                    ...months.map((m) => DropdownMenuItem(value: m, child: Text(DateFormat('MMM').format(DateTime(2000, m)), style: const TextStyle(fontSize: 13)))),
                  ],
                  onChanged: (val) {
                    _onStartMonthChanged(val);
                  },
                ),
              ),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text('to', style: TextStyle(fontSize: 13))),
              Expanded(
                flex: 3,
                child: _buildDropdown<int?>(
                  value: _endMonth,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('End', style: TextStyle(fontSize: 13))),
                    ...months.where((m) => _startMonth == null || m >= _startMonth!).map((m) => DropdownMenuItem(value: m, child: Text(DateFormat('MMM').format(DateTime(2000, m)), style: const TextStyle(fontSize: 13)))),
                  ],
                  onChanged: (val) {
                    _onEndMonthChanged(val);
                  },
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
    final totalExams = summaries.fold(0, (s, b) => s + b.totalExams);
    final totalAbsents = summaries.fold(0, (s, b) => s + b.absentCount);
    final totalObtained = summaries.fold(0.0, (s, b) => s + b.totalObtained);
    final totalAvailable = summaries.fold(0.0, (s, b) => s + b.totalAvailable);
    final overallAvg = totalAvailable > 0 ? (totalObtained / totalAvailable) * 100 : 0.0;

    final bannerLabel = _selectedBatchId == null
        ? 'All Batches — $_selectedYear'
        : '${summaries.isNotEmpty ? summaries.first.batchName : "Selected Batch"} — $_selectedYear';

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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.analytics, color: Colors.white70, size: 18),
                          const SizedBox(width: 8),
                          Text(bannerLabel, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                      if (_selectedBatchId != null)
                        ElevatedButton.icon(
                          onPressed: () async {
                            showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
                            
                            await examProvider.loadDetailedResultsByBatch(_selectedBatchId, year: _selectedYear, startMonth: _startMonth, endMonth: _endMonth);
                            
                            if (!mounted) return;

                            final allResults = examProvider.batchSummaryResults;
                            final students = context.read<StudentProvider>().students;
                            
                            Map<Student, List<DetailedResult>> grouped = {};
                            for (var s in students) {
                              grouped[s] = allResults.where((r) => r.studentId == s.id).toList();
                            }
                            
                            final profile = context.read<ProfileProvider>().profile;
                            final pdfBytes = await PdfReportService.generateBatchReport(
                              batchName: summaries.isNotEmpty ? summaries.first.batchName : "Unknown Batch",
                              studentResultsMap: grouped,
                              periodLabel: _currentPeriodLabel,
                              instituteName: profile?.instituteName,
                              ownerName: profile?.ownerName,
                              ownerPhone: profile?.phone,
                            );
                            
                            if (!mounted) return;
                            Navigator.pop(context);
                            
                            await Printing.layoutPdf(
                              onLayout: (PdfPageFormat format) async => pdfBytes,
                              name: '${summaries.isNotEmpty ? summaries.first.batchName : "Unknown_Batch"}_Report.pdf',
                            );
                          },
                          icon: const Icon(Icons.print, size: 14),
                          label: const Text('Print All', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF191A4E),
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildBannerStat('Total Exams', totalExams.toString()),
                      _buildBannerStat('Avg Score', '${overallAvg.toCleanString()}%'),
                      _buildBannerStat('Absents', totalAbsents.toString()),
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
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F4F8),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.group, color: Color(0xFF191A4E), size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  b.batchName, 
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8,
                                  runSpacing: 2,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.people_outline, size: 14, color: Colors.black54),
                                        const SizedBox(width: 4),
                                        Text('${b.totalStudents} Students', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                      ],
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.assignment_outlined, size: 14, color: Colors.black54),
                                        const SizedBox(width: 4),
                                        Text('${b.totalExams} Exams', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: bColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${b.avgPercent.toCleanString()}%',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: bColor, height: 1.1),
                                ),
                                Text(
                                  'Avg Score',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10, color: bColor, height: 1.1),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (b.avgPercent / 100).clamp(0.0, 1.0),
                          minHeight: 5,
                          backgroundColor: Colors.grey.shade100,
                          valueColor: AlwaysStoppedAnimation<Color>(bColor),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildBatchStatPill(Icons.fact_check, '${b.attendanceRate.toCleanString()}% Attendance', const Color(0xFF1A73E8)),
                            const SizedBox(width: 8),
                            _buildBatchStatPill(Icons.how_to_reg, '${b.presentStudents} Present', const Color(0xFF2B9348)),
                            const SizedBox(width: 8),
                            _buildBatchStatPill(Icons.person_off, '${b.absentCount} Absent', const Color(0xFFD32F2F)),
                            const SizedBox(width: 8),
                            _buildBatchStatPill(Icons.military_tech, '${b.totalAvailable.toCleanString()} Marks', const Color(0xFFF57C00)),
                          ],
                        ),
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
        mainAxisSize: MainAxisSize.min,
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
              Text('No exams found for this period', style: const TextStyle(color: Colors.black54, fontSize: 16)),
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
        final pct = r.totalMarks > 0 ? (r.obtainedMarks! / r.totalMarks) * 100 : 0.0;
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
                ElevatedButton.icon(
                  onPressed: () async {
                    final profile = context.read<ProfileProvider>().profile;
                    final batchName = _selectedBatchId != null 
                        ? context.read<BatchProvider>().batches.firstWhere((b) => b.id == _selectedBatchId).name 
                        : null;
                    final pdfBytes = await PdfReportService.generateStudentReport(
                      student: _selectedStudent!,
                      results: yearResults,
                      periodLabel: _currentPeriodLabel,
                      instituteName: profile?.instituteName,
                      ownerName: profile?.ownerName,
                      ownerPhone: profile?.phone,
                      batchName: batchName,
                    );
                    await Printing.layoutPdf(
                      onLayout: (PdfPageFormat format) async => pdfBytes,
                      name: '${_selectedStudent!.name}_Report.pdf',
                    );
                  },
                  icon: const Icon(Icons.print, size: 16),
                  label: const Text('Print', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF191A4E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
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
                Expanded(child: _buildStatCard('Average', '${overallAverage.toCleanString()}%', Icons.show_chart, const Color(0xFF2B9348))),
                const SizedBox(width: 8),
                Expanded(child: _buildStatCard('Highest', '${maxPercentage.toCleanString()}%', Icons.arrow_upward, const Color(0xFFF57C00))),
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
                        '${totalMarksObtained.toCleanString()} / ${totalMarksAvailable.toCleanString()}',
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
                          '${overallAverage.toCleanString(maxDecimals: 2)}%',
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
      statusText = '${result.obtainedMarks?.toCleanString()} / ${result.totalMarks.toCleanString()}';
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
                Text(
                  result.examTitle, 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${result.displayBatchName} • ${result.examType}', 
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
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
                  child: Text('${percentage!.toCleanString()}%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: statusColor)),
                ),
              ]
            ],
          ),
        ],
      ),
    );
  }
}
