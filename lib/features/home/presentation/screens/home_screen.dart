import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

import '../../../student/presentation/providers/student_provider.dart';
import '../../../batch/presentation/providers/batch_provider.dart';
import '../../../exam/presentation/providers/exam_provider.dart';
import '../../../enrollment/presentation/providers/enrollment_provider.dart';

import '../../../student/presentation/screens/student_form_screen.dart';
import '../../../student/presentation/screens/student_list_screen.dart';
import '../../../fee/presentation/screens/fee_overview_screen.dart';
import '../../../exam/presentation/screens/exam_list_screen.dart';
import '../../../routine/presentation/screens/routine_screen.dart';

import '../../../../core/widgets/app_drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int? _selectedBatchId;

  String _getGreeting() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 6));
    final hour = now.hour;
    if (hour >= 5 && hour < 12) {
      return 'Good Morning';
    } else if (hour >= 12 && hour < 17) {
      return 'Good Afternoon';
    } else if (hour >= 17 && hour < 21) {
      return 'Good Evening';
    } else {
      return 'Good Night';
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudentProvider>().loadStudents();
      context.read<BatchProvider>().loadBatches();
      context.read<ExamProvider>().loadAllExams();
      context.read<EnrollmentProvider>().loadEnrollments();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: const AppDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 20),
              _buildDateAndBatchRow(),
              const SizedBox(height: 20),
              _buildQuoteBanner(),
              const SizedBox(height: 24),
              _buildSectionTitle('Quick Actions'),
              const SizedBox(height: 16),
              _buildQuickActionsGrid(context),
              const SizedBox(height: 24),
              _buildSectionTitle('Quick Overview'),
              const SizedBox(height: 16),
              _buildQuickOverviewRow(),
              const SizedBox(height: 24),
              _buildFooterBanner(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))
            ],
          ),
          child: Builder(
            builder: (context) {
              return InkWell(
                onTap: () => Scaffold.of(context).openDrawer(),
                child: const Icon(Icons.menu, color: Colors.black87),
              );
            },
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_getGreeting()}, Teacher! 👋',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Have a productive day ahead.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateAndBatchRow() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 6));
    final dayName = DateFormat('EEEE').format(now);
    final dateStr = DateFormat('dd MMMM yyyy').format(now);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F0FE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.calendar_today, color: Color(0xFF1A73E8), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(dayName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
                        Text(dateStr, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Consumer<BatchProvider>(
              builder: (context, batchProvider, _) {
                final batches = batchProvider.batches;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E5F5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.group_outlined, color: Color(0xFF8E24AA), size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton2<int?>(
                            value: _selectedBatchId,
                            isExpanded: true,
                            iconStyleData: const IconStyleData(
                              icon: Icon(Icons.keyboard_arrow_down, color: Colors.black87, size: 20),
                            ),
                            dropdownStyleData: DropdownStyleData(
                              maxHeight: 300,
                              width: 220,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.white,
                              ),
                              offset: const Offset(0, -8),
                            ),
                            menuItemStyleData: const MenuItemStyleData(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                            ),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('All Batches')),
                              ...batches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))),
                            ],
                            onChanged: (val) {
                              setState(() => _selectedBatchId = val);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFF42A5F5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.format_quote, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Teaching is the one profession that creates all other professions.',
              style: TextStyle(fontStyle: FontStyle.italic, color: Color(0xFF1565C0), fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.menu_book, color: Color(0xFF1E88E5), size: 40),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, {VoidCallback? onEdit, VoidCallback? onViewAll}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
        if (onEdit != null)
          InkWell(
            onTap: onEdit,
            child: Row(
              children: const [
                Text('Edit ', style: TextStyle(color: Color(0xFF1A73E8), fontSize: 13, fontWeight: FontWeight.w600)),
                Icon(Icons.edit, color: Color(0xFF1A73E8), size: 14),
              ],
            ),
          ),
        if (onViewAll != null)
          InkWell(
            onTap: onViewAll,
            child: Row(
              children: const [
                Text('View All ', style: TextStyle(color: Color(0xFF1A73E8), fontSize: 13, fontWeight: FontWeight.w600)),
                Icon(Icons.arrow_forward_ios, color: Color(0xFF1A73E8), size: 12),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 0.95,
      children: [
        _buildActionCard(
          title: 'Add\nStudent',
          icon: Icons.person_add_alt_1,
          color: const Color(0xFF1A73E8),
          bgColor: const Color(0xFFE8F0FE),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentFormScreen())),
        ),
        _buildActionCard(
          title: 'Add\nPayment',
          icon: Icons.account_balance_wallet,
          color: const Color(0xFF2B9348),
          bgColor: const Color(0xFFE8F8EE),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FeeOverviewScreen())),
        ),
        _buildActionCard(
          title: 'Add\nExam Result',
          icon: Icons.assignment_turned_in,
          color: const Color(0xFFF57C00),
          bgColor: const Color(0xFFFFF3E0),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExamListScreen())),
        ),
        _buildActionCard(
          title: 'Add\nRoutine',
          icon: Icons.calendar_month,
          color: const Color(0xFF7B1FA2),
          bgColor: const Color(0xFFF3E5F5),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RoutineScreen())),
        ),
        _buildActionCard(
          title: 'Result\nAnalytics',
          icon: Icons.analytics,
          color: const Color(0xFFD81B60),
          bgColor: const Color(0xFFFCE4EC),
          onTap: () => Navigator.pushNamed(context, '/result-analytics'),
        ),
        _buildActionCard(
          title: 'View\nAll Students',
          icon: Icons.people_alt,
          color: const Color(0xFF00ACC1),
          bgColor: const Color(0xFFE0F7FA),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentListScreen())),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickOverviewRow() {
    return Consumer3<StudentProvider, BatchProvider, ExamProvider>(
      builder: (context, studentProvider, batchProvider, examProvider, _) {
        final enrollments = context.read<EnrollmentProvider>().enrollments;
        
        // Filter students by selected batch
        var students = studentProvider.students;
        if (_selectedBatchId != null) {
          final batchStudentIds = enrollments
              .where((e) => e.batchId == _selectedBatchId)
              .map((e) => e.studentId)
              .toSet();
          students = students.where((s) => batchStudentIds.contains(s.id)).toList();
        }

        final totalStudents = students.length;
        
        // Active Students Logic
        int activeStudents = 0;
        for (var s in students) {
          final sEnrollments = enrollments.where((e) => e.studentId == s.id);
          if (_selectedBatchId != null) {
            if (sEnrollments.any((e) => e.batchId == _selectedBatchId && e.leaveDate == null)) {
              activeStudents++;
            }
          } else {
            if (sEnrollments.any((e) => e.leaveDate == null)) {
              activeStudents++;
            }
          }
        }

        final totalBatches = _selectedBatchId == null ? batchProvider.batches.length : 1;
        
        // Upcoming exams logic
        final today = DateTime.now().toUtc().add(const Duration(hours: 6));
        var exams = examProvider.exams;
        if (_selectedBatchId != null) {
          exams = exams.where((e) => e.batchId == _selectedBatchId).toList();
        }
        final upcomingExams = exams.where((e) => e.examDate.isAfter(today) || (e.examDate.year == today.year && e.examDate.month == today.month && e.examDate.day == today.day)).length;

        return Row(
          children: [
            Expanded(child: _buildOverviewStatCard(totalStudents.toString(), 'Total Students', Icons.people, const Color(0xFF1A73E8), const Color(0xFFE8F0FE))),
            const SizedBox(width: 8),
            Expanded(child: _buildOverviewStatCard(activeStudents.toString(), 'Active Students', Icons.how_to_reg, const Color(0xFF2B9348), const Color(0xFFE8F8EE))),
            const SizedBox(width: 8),
            Expanded(child: _buildOverviewStatCard(totalBatches.toString(), 'Total Batches', Icons.school, const Color(0xFFF57C00), const Color(0xFFFFF3E0))),
            const SizedBox(width: 8),
            Expanded(child: _buildOverviewStatCard(upcomingExams.toString(), 'Upcoming Exams', Icons.assignment, const Color(0xFF7B1FA2), const Color(0xFFF3E5F5))),
          ],
        );
      },
    );
  }

  Widget _buildOverviewStatCard(String value, String label, IconData icon, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildFooterBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FE),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.book, color: Color(0xFF1A73E8), size: 40),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Everything you need,\norganized and simple.',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Color(0xFFFFC107), shape: BoxShape.circle),
            child: const Icon(Icons.sentiment_satisfied_alt, color: Colors.white, size: 24),
          ),
        ],
      ),
    );
  }
}
