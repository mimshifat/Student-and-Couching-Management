import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/student.dart';
import 'student_form_screen.dart';
import '../../../enrollment/presentation/providers/enrollment_provider.dart';
import '../../../enrollment/presentation/widgets/enrollment_history_widget.dart';
import '../widgets/student_performance_widget.dart';
import '../widgets/student_fee_history_widget.dart';

class StudentDetailScreen extends StatelessWidget {
  final Student student;

  const StudentDetailScreen({super.key, required this.student});

  static const Color primaryNavy = Color(0xFF191A4E);

  @override
  Widget build(BuildContext context) {
    // Generate STU ID
    final studentIdStr = 'STU${student.id?.toString().padLeft(4, '0') ?? '0000'}';

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: primaryNavy,
          elevation: 0,
          centerTitle: true,
          title: const Text('Student Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white, size: 20),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StudentFormScreen(student: student),
                  ),
                );
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // Top Section (White Background)
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  _buildProfileHeader(context, studentIdStr),
                  const Divider(height: 1, color: Color(0xFFF0F0F0)),
                  _buildDetailsList(context),
                  const Divider(height: 1, color: Color(0xFFF0F0F0)),
                  _buildTabBar(),
                ],
              ),
            ),
            // Bottom Section (Tab Views)
            Expanded(
              child: TabBarView(
                children: [
                  _wrapTabContent(EnrollmentHistoryWidget(studentId: student.id!)),
                  _wrapTabContent(StudentFeeHistoryWidget(studentId: student.id!)),
                  _wrapTabContent(StudentPerformanceWidget(studentId: student.id!)),
                  _wrapTabContent(const Center(child: Text('Exams module in development', style: TextStyle(color: Colors.grey)))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wrapTabContent(Widget child) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: child,
    );
  }

  Widget _buildProfileHeader(BuildContext context, String studentIdStr) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: const Color(0xFF3B41C5),
            child: Text(
              _getInitials(student.name),
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        student.name,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusBadge(context),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Class ${student.className ?? '-'} • Roll ${student.rollNumber ?? '-'}',
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 4),
                Text(
                  'Student ID: $studentIdStr',
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    return Consumer<EnrollmentProvider>(
      builder: (context, provider, child) {
        final enrollments = provider.enrollments.where((e) => e.studentId == student.id);
        final isRunning = enrollments.any((e) => e.leaveDate == null);

        final text = isRunning ? 'Running' : 'Previous';
        final bgColor = isRunning ? const Color(0xFFE8F8EE) : const Color(0xFFF3E5F5);
        final textColor = isRunning ? const Color(0xFF2B9348) : const Color(0xFF7B1FA2);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            text,
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        );
      },
    );
  }

  Widget _buildDetailsList(BuildContext context) {
    final admissionDateStr = DateFormat('dd MMM yyyy').format(student.createdAt);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        children: [
          _buildDetailRow(Icons.phone_outlined, 'Phone', student.phone ?? '-'),
          const SizedBox(height: 12),
          _buildDetailRow(Icons.person_outline, 'Guardian', student.guardianName ?? '-'),
          const SizedBox(height: 12),
          _buildDetailRow(Icons.contact_phone_outlined, 'Guardian Phone', student.guardianPhone ?? '-'),
          const SizedBox(height: 12),
          _buildDetailRow(Icons.school_outlined, 'School / College', student.schoolCollege ?? '-'),
          const SizedBox(height: 12),
          _buildDetailRow(Icons.calendar_today_outlined, 'Admission Date', admissionDateStr),
          const SizedBox(height: 12),
          _buildStatusDetailRow(context),
        ],
      ),
    );
  }

  Widget _buildStatusDetailRow(BuildContext context) {
    return Consumer<EnrollmentProvider>(
      builder: (context, provider, child) {
        final enrollments = provider.enrollments.where((e) => e.studentId == student.id);
        final isRunning = enrollments.any((e) => e.leaveDate == null);
        return _buildDetailRow(Icons.verified_user_outlined, 'Status', isRunning ? 'Running' : 'Previous');
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.black54),
        const SizedBox(width: 12),
        SizedBox(
          width: 130,
          child: Text(label, style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 14, color: Colors.black87)),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return const TabBar(
      labelColor: Color(0xFF3B41C5),
      unselectedLabelColor: Colors.black54,
      indicatorColor: Color(0xFF3B41C5),
      indicatorWeight: 3,
      labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      tabs: [
        Tab(text: 'Enrollment'),
        Tab(text: 'Payments'),
        Tab(text: 'Progress'),
        Tab(text: 'Exam'),
      ],
    );
  }

  String _getInitials(String name) {
    List<String> parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}
