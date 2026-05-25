import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/routine.dart';
import '../providers/routine_provider.dart';
import '../../../batch/presentation/providers/batch_provider.dart';
import '../../../../core/widgets/custom_form_widgets.dart';

class RoutineFormScreen extends StatefulWidget {
  final Routine? routine;

  const RoutineFormScreen({super.key, this.routine});

  @override
  State<RoutineFormScreen> createState() => _RoutineFormScreenState();
}

class _RoutineFormScreenState extends State<RoutineFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  int? _selectedBatchId;
  String? _selectedDay;
  late TextEditingController _subjectCtrl;
  late TextEditingController _teacherCtrl;
  
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  final List<String> _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  @override
  void initState() {
    super.initState();
    _selectedBatchId = widget.routine?.batchId;
    _selectedDay = widget.routine?.dayOfWeek;
    _subjectCtrl = TextEditingController(text: widget.routine?.subject ?? '');
    _teacherCtrl = TextEditingController(text: widget.routine?.teacherName ?? '');
    
    if (widget.routine != null) {
      _startTime = _parseTime(widget.routine!.startTime);
      _endTime = _parseTime(widget.routine!.endTime);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BatchProvider>().loadBatches();
    });
  }

  TimeOfDay? _parseTime(String timeString) {
    try {
      final format = DateFormat.jm(); // 6:00 AM
      final dateTime = format.parse(timeString);
      return TimeOfDay.fromDateTime(dateTime);
    } catch (e) {
      return null;
    }
  }
  
  String _formatTime(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    final format = DateFormat.jm();
    return format.format(dt);
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _teacherCtrl.dispose();
    super.dispose();
  }

  void _save() async {
    if (_selectedBatchId == null || _selectedDay == null || _startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields')));
      return;
    }

    if (_formKey.currentState!.validate()) {
      final newRoutine = Routine(
        id: widget.routine?.id,
        batchId: _selectedBatchId!,
        dayOfWeek: _selectedDay!,
        startTime: _formatTime(_startTime!),
        endTime: _formatTime(_endTime!),
        subject: _subjectCtrl.text.trim(),
        teacherName: _teacherCtrl.text.trim().isEmpty ? null : _teacherCtrl.text.trim(),
        createdAt: widget.routine?.createdAt ?? DateTime.now(),
      );

      final provider = context.read<RoutineProvider>();
      final success = widget.routine == null 
        ? await provider.addRoutine(newRoutine)
        : await provider.updateRoutine(newRoutine);
        
      if (success && mounted) {
        Navigator.pop(context);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.errorMessage ?? 'An error occurred')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CustomFormWidgets.backgroundColor,
      appBar: CustomFormWidgets.buildAppBar(
        title: widget.routine == null ? 'Add Routine' : 'Edit Routine',
        subtitle: 'Schedule a class',
        onSave: _save,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomFormWidgets.buildSectionHeader('Class Details', Icons.schedule_outlined),
                      const SizedBox(height: 20),
                      Consumer<BatchProvider>(
                        builder: (context, batchProvider, child) {
                          if (batchProvider.isLoading) return const CircularProgressIndicator();
                          if (batchProvider.batches.isEmpty) return const Text('No batches available.');
                          
                          return CustomFormWidgets.buildDropdown<int>(
                            label: 'Batch *',
                            icon: Icons.class_outlined,
                            value: _selectedBatchId,
                            items: batchProvider.batches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name, style: const TextStyle(fontSize: 14)))).toList(),
                            onChanged: (val) => setState(() => _selectedBatchId = val),
                            validator: (val) => val == null ? 'Required' : null,
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      CustomFormWidgets.buildDropdown<String>(
                        label: 'Day of Week *',
                        icon: Icons.calendar_view_day_outlined,
                        value: _selectedDay,
                        items: _days.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 14)))).toList(),
                        onChanged: (val) => setState(() => _selectedDay = val),
                        validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      CustomFormWidgets.buildTextField(
                        label: 'Subject *',
                        hint: 'e.g. Higher Math',
                        icon: Icons.menu_book_outlined,
                        controller: _subjectCtrl,
                        validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      CustomFormWidgets.buildTextField(
                        label: 'Teacher Name (Optional)',
                        hint: 'e.g. John Doe',
                        icon: Icons.person_outline,
                        controller: _teacherCtrl,
                      ),
                      
                      const SizedBox(height: 32),
                      CustomFormWidgets.buildSectionHeader('Timing', Icons.access_time),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTimePickerField('Start Time *', _startTime, (time) => setState(() => _startTime = time)),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTimePickerField('End Time *', _endTime, (time) => setState(() => _endTime = time)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            CustomFormWidgets.buildBottomBar(
              context: context,
              onCancel: () => Navigator.pop(context),
              onSave: _save,
              saveLabel: widget.routine == null ? 'Save Routine' : 'Update Routine',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePickerField(String label, TimeOfDay? time, Function(TimeOfDay) onSelected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CustomFormWidgets.primaryColor)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: time ?? TimeOfDay.now(),
            );
            if (picked != null) onSelected(picked);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time, color: Colors.grey.shade500, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    time == null ? 'Select Time' : _formatTime(time),
                    style: TextStyle(fontSize: 14, color: time == null ? Colors.grey.shade500 : Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
