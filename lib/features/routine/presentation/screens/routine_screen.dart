import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/routine_provider.dart';
import '../../../batch/domain/entities/batch.dart';

class RoutineScreen extends StatefulWidget {
  final Batch batch;

  const RoutineScreen({super.key, required this.batch});

  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RoutineProvider>().loadRoutinesByBatch(widget.batch.id!);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.batch.name} Routine')),
      body: Consumer<RoutineProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.routines.isEmpty) {
            return const EmptyStateWidget(
              message: 'No routine classes scheduled.',
              icon: Icons.calendar_month,
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: provider.routines.length,
            itemBuilder: (context, index) {
              final r = provider.routines[index];
              return AppCard(
                child: ListTile(
                  title: Text(r.subject, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${r.dayOfWeek} • ${r.startTime} - ${r.endTime}\nTeacher: ${r.teacherName ?? 'N/A'}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: AppTheme.errorColor),
                    onPressed: () {
                      provider.deleteRoutine(r.id!, widget.batch.id!);
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
