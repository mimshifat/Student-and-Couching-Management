import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/routine_provider.dart';
import '../../../batch/domain/entities/batch.dart';
import '../../domain/entities/routine.dart';

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

  void _showRoutineForm(BuildContext context, [Routine? routine]) {
    final subjectCtrl = TextEditingController(text: routine?.subject);
    final teacherCtrl = TextEditingController(text: routine?.teacherName);
    String day = routine?.dayOfWeek ?? 'Monday';
    String startTime = routine?.startTime ?? '09:00 AM';
    String endTime = routine?.endTime ?? '10:00 AM';

    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 16, right: 16, top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(routine == null ? 'Add Routine' : 'Edit Routine', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Day of Week'),
                    initialValue: day,
                    items: days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    onChanged: (val) => setSheetState(() => day = val!),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: TextFormField(initialValue: startTime, decoration: const InputDecoration(labelText: 'Start Time'), onChanged: (v) => startTime = v)),
                      const SizedBox(width: 16),
                      Expanded(child: TextFormField(initialValue: endTime, decoration: const InputDecoration(labelText: 'End Time'), onChanged: (v) => endTime = v)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(controller: subjectCtrl, decoration: const InputDecoration(labelText: 'Subject *')),
                  const SizedBox(height: 16),
                  TextField(controller: teacherCtrl, decoration: const InputDecoration(labelText: 'Teacher Name')),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (subjectCtrl.text.trim().isEmpty) return;
                        final newRoutine = Routine(
                          id: routine?.id,
                          batchId: widget.batch.id!,
                          dayOfWeek: day,
                          startTime: startTime,
                          endTime: endTime,
                          subject: subjectCtrl.text.trim(),
                          teacherName: teacherCtrl.text.trim(),
                          createdAt: routine?.createdAt ?? DateTime.now(),
                        );
                        final provider = context.read<RoutineProvider>();
                        if (routine == null) {
                          await provider.addRoutine(newRoutine);
                        } else {
                          await provider.updateRoutine(newRoutine);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Save'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
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
                  trailing: PopupMenuButton<String>(
                    onSelected: (val) {
                      if (val == 'edit') {
                        _showRoutineForm(context, r);
                      } else if (val == 'delete') {
                        provider.deleteRoutine(r.id!, widget.batch.id!);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppTheme.errorColor))),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showRoutineForm(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
