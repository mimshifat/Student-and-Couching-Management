import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/student.dart';
import '../providers/student_provider.dart';
import 'student_form_screen.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../enrollment/presentation/widgets/enrollment_history_widget.dart';
import '../widgets/student_performance_widget.dart';
import '../../../../core/theme/app_theme.dart';

class StudentDetailScreen extends StatelessWidget {
  final Student student;

  const StudentDetailScreen({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StudentFormScreen(student: student),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => const ConfirmDialog(
                  title: 'Delete Student',
                  content: 'Are you sure you want to delete this student? All related data will be lost.',
                ),
              );
              if (confirm == true) {
                if (context.mounted) {
                  await context.read<StudentProvider>().deleteStudent(student.id!);
                  if (context.mounted) Navigator.pop(context);
                }
              }
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  child: Text(student.name[0].toUpperCase(), style: const TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(student.name, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      StatusBadge(status: student.status),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Contact Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  _buildInfoRow('Phone', student.phone),
                  _buildInfoRow('Guardian Name', student.guardianName),
                  _buildInfoRow('Guardian Phone', student.guardianPhone),
                ],
              ),
            ),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Academic & Billing', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  _buildInfoRow('School/College', student.schoolCollege),
                  _buildInfoRow('Class', student.className),
                  _buildInfoRow('Roll Number', student.rollNumber?.toString()),
                  _buildInfoRow('Admission Date', DateFormat('dd MMM yyyy').format(student.admissionDate)),
                  _buildInfoRow('Monthly Fee', '৳${student.monthlyFee.toStringAsFixed(2)}'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            EnrollmentHistoryWidget(studentId: student.id!),
            const SizedBox(height: 16),
            StudentPerformanceWidget(studentId: student.id!),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    
    bool isPhone = label.toLowerCase().contains('phone');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: isPhone ? GestureDetector(
              onTap: () async {
                final url = Uri.parse('tel:$value');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                }
              },
              child: Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: AppTheme.primaryColor,
                  decoration: TextDecoration.underline,
                ),
              ),
            ) : Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
