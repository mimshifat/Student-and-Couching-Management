import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/batch.dart';
import 'batch_form_screen.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../enrollment/presentation/providers/enrollment_provider.dart';
import '../../../enrollment/domain/entities/enrollment.dart';
import '../../../enrollment/presentation/screens/batch_student_enrollment_screen.dart';
import '../../../student/presentation/providers/student_provider.dart';
import '../../../student/presentation/screens/student_detail_screen.dart';

class BatchDetailScreen extends StatefulWidget {
  final Batch batch;

  const BatchDetailScreen({super.key, required this.batch});

  @override
  State<BatchDetailScreen> createState() => _BatchDetailScreenState();
}

class _BatchDetailScreenState extends State<BatchDetailScreen> {
  static const Color primaryNavy = Color(0xFF191A4E);
  late Future<List<Enrollment>> _studentsFuture;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  void _loadStudents() {
    _studentsFuture = context.read<EnrollmentProvider>().getStudentsByBatch(widget.batch.id!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(widget.batch.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: primaryNavy,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => BatchFormScreen(batch: widget.batch)),
              ).then((_) {
                setState(() {}); // refresh batch details if changed
              });
            },
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildHeaderInfo(),
          ),
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Enrolled Students', 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: _buildStudentList(),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 80), // Padding for FAB
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryNavy,
        foregroundColor: Colors.white,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BatchStudentEnrollmentScreen(batch: widget.batch),
            ),
          ).then((_) {
            _loadStudents();
            setState(() {});
          });
        },
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add Student', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildHeaderInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.class_outlined, color: AppTheme.primaryColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.batch.name,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Batch Fee: ৳${widget.batch.monthlyFee.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (widget.batch.scheduleDays != null || widget.batch.timeSlot != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(),
            ),
            if (widget.batch.scheduleDays != null && widget.batch.scheduleDays!.isNotEmpty)
              _buildInfoRow(Icons.calendar_month_outlined, 'Schedule', widget.batch.scheduleDays!),
            if (widget.batch.timeSlot != null && widget.batch.timeSlot!.isNotEmpty)
              _buildInfoRow(Icons.access_time_outlined, 'Time', widget.batch.timeSlot!),
          ],
          if (widget.batch.description != null && widget.batch.description!.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(),
            ),
            const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
            const SizedBox(height: 8),
            Text(widget.batch.description!, style: const TextStyle(color: Colors.black54, fontSize: 14)),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                Text(value, style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentList() {
    return FutureBuilder<List<Enrollment>>(
      future: _studentsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
              ),
            ),
          );
        }
        
        final students = snapshot.data ?? [];
        if (students.isEmpty) {
          return SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(32),
              margin: const EdgeInsets.only(top: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Column(
                children: [
                  Icon(Icons.people_outline, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No students enrolled yet',
                    style: TextStyle(fontSize: 16, color: Colors.black54, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Click the add button below to enroll students into this batch.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.black38),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final e = students[index];
              final studentProvider = context.read<StudentProvider>();
              final student = studentProvider.students.where((s) => s.id == e.studentId).firstOrNull;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                    foregroundColor: AppTheme.primaryColor,
                    radius: 24,
                    child: Text(
                      (e.studentName != null && e.studentName!.isNotEmpty) ? e.studentName![0].toUpperCase() : '?',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  title: Text(
                    e.studentName ?? 'Unknown Student',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      if (student != null)
                        Text(
                          'Class: ${student.className ?? 'N/A'} • Roll: ${student.rollNumber ?? 'N/A'}',
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      if (student != null && student.phone != null && student.phone!.isNotEmpty)
                        Text(
                          student.phone!,
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        'Joined: ${e.joinDate.toLocal().toString().split(' ')[0]}',
                        style: const TextStyle(color: Colors.black54, fontSize: 12),
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    if (student != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StudentDetailScreen(student: student),
                        ),
                      );
                    }
                  },
                ),
              );
            },
            childCount: students.length,
          ),
        );
      },
    );
  }
}
