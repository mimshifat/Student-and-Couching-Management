import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/batch.dart';
import '../providers/batch_provider.dart';
import 'batch_form_screen.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../routine/presentation/screens/routine_screen.dart';

class BatchDetailScreen extends StatelessWidget {
  final Batch batch;

  const BatchDetailScreen({super.key, required this.batch});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(batch.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => BatchFormScreen(batch: batch)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RoutineScreen(batch: batch)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => const ConfirmDialog(
                  title: 'Delete Batch',
                  content: 'Are you sure? This will delete the batch and remove students from it.',
                ),
              );
              if (confirm == true) {
                if (context.mounted) {
                  await context.read<BatchProvider>().deleteBatch(batch.id!);
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
            if (batch.description != null && batch.description!.isNotEmpty)
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(batch.description!),
                  ],
                ),
              ),
            // Placeholders for Enrollment/Student list inside this batch
            // AppCard(child: Text('Enrolled Students List Here')),
            // AppCard(child: Text('Exams for this Batch Here')),
            // AppCard(child: Text('Routine for this Batch Here')),
          ],
        ),
      ),
    );
  }
}
