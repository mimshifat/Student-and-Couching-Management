import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/batch.dart';
import 'batch_form_screen.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../routine/presentation/screens/routine_screen.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../enrollment/presentation/providers/enrollment_provider.dart';
import '../../../enrollment/domain/entities/enrollment.dart';

class BatchDetailScreen extends StatefulWidget {
  final Batch batch;

  const BatchDetailScreen({super.key, required this.batch});

  @override
  State<BatchDetailScreen> createState() => _BatchDetailScreenState();
}

class _BatchDetailScreenState extends State<BatchDetailScreen> {
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
      appBar: AppBar(
        title: Text(widget.batch.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => BatchFormScreen(batch: widget.batch)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RoutineScreen(batch: widget.batch)),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.batch.description != null && widget.batch.description!.isNotEmpty)
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(widget.batch.description!),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            const Text('Enrolled Students', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            FutureBuilder<List<Enrollment>>(
              future: _studentsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                
                final students = snapshot.data ?? [];
                if (students.isEmpty) {
                  return const AppCard(child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No active students in this batch.'),
                  ));
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final e = students[index];
                    return AppCard(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                          foregroundColor: AppTheme.primaryColor,
                          child: const Icon(Icons.person),
                        ),
                        title: Text(e.studentName ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Discount: ৳${e.discountAmount.toStringAsFixed(0)}'),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
