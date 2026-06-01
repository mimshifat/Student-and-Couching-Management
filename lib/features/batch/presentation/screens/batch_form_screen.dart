import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/batch.dart';
import '../providers/batch_provider.dart';
import '../../../../core/widgets/custom_form_widgets.dart';

class BatchFormScreen extends StatefulWidget {
  final Batch? batch;

  const BatchFormScreen({super.key, this.batch});

  @override
  State<BatchFormScreen> createState() => _BatchFormScreenState();
}

class _BatchFormScreenState extends State<BatchFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _feeCtrl;
  bool _isActive = true;
  DateTime? _inactiveStartDate;
  DateTime? _activationDate;
  String? _scheduleDays;
  String? _timeSlot;
  
  final List<String> _daysOptions = [
    'Everyday',
    'Saturday-Monday-Wednesday',
    'Sunday-Tuesday-Thursday'
  ];

  late final List<String> _timeSlotOptions;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.batch?.name ?? '');
    _descCtrl = TextEditingController(text: widget.batch?.description ?? '');
    _feeCtrl = TextEditingController(text: widget.batch?.monthlyFee.toString() ?? '0.0');
    _isActive = widget.batch?.isActive ?? true;
    _scheduleDays = widget.batch?.scheduleDays;
    _timeSlot = widget.batch?.timeSlot;
    
    _timeSlotOptions = _generateTimeSlots();
  }

  List<String> _generateTimeSlots() {
    List<String> slots = [];
    // 4 AM to 9 PM starts
    for (int i = 4; i <= 21; i++) {
      int next = i + 1;
      
      String formatHour(int h) {
        int hour = h > 12 ? h - 12 : h;
        String ampm = h >= 12 && h < 24 ? 'PM' : 'AM';
        return '$hour:00 $ampm';
      }
      
      slots.add('${formatHour(i)} - ${formatHour(next)}');
    }
    return slots;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _feeCtrl.dispose();
    super.dispose();
  }

  void _save() async {
    if (_formKey.currentState!.validate()) {
      final b = Batch(
        id: widget.batch?.id,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        scheduleDays: _scheduleDays,
        timeSlot: _timeSlot,
        monthlyFee: double.tryParse(_feeCtrl.text.trim()) ?? 0.0,
        isActive: _isActive,
        createdAt: widget.batch?.createdAt ?? DateTime.now(),
      );

      final provider = context.read<BatchProvider>();
      bool success;
      if (widget.batch == null) {
        success = await provider.addBatch(b);
      } else {
        success = await provider.updateBatch(b, inactiveStartDate: _inactiveStartDate, activationDate: _activationDate);
      }

      if (success && mounted) {
        Navigator.pop(context);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.errorMessage ?? 'An error occurred')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CustomFormWidgets.backgroundColor,
      appBar: CustomFormWidgets.buildAppBar(
        title: widget.batch == null ? 'Add Batch' : 'Edit Batch',
        subtitle: 'Enter batch information',
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
                      CustomFormWidgets.buildSectionHeader('Batch Details', Icons.class_outlined),
                      const SizedBox(height: 20),
                      CustomFormWidgets.buildTextField(
                        label: 'Batch Name *',
                        hint: 'e.g. Science Batch 2026',
                        icon: Icons.title,
                        controller: _nameCtrl,
                        validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      CustomFormWidgets.buildTextField(
                        label: 'Description',
                        hint: 'Optional details about the batch',
                        icon: Icons.description_outlined,
                        controller: _descCtrl,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      CustomFormWidgets.buildTextField(
                        label: 'Monthly Fee *',
                        hint: 'Enter monthly fee',
                        prefixText: '৳ ',
                        controller: _feeCtrl,
                        isNumber: true,
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Required';
                          if (double.tryParse(val) == null) return 'Invalid number';
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      CustomFormWidgets.buildSectionHeader('Schedule', Icons.calendar_today_outlined),
                      const SizedBox(height: 16),
                      CustomFormWidgets.buildDropdown<String>(
                        label: 'Schedule Days',
                        icon: Icons.calendar_month,
                        value: _scheduleDays,
                        items: _daysOptions.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(),
                        onChanged: (val) => setState(() => _scheduleDays = val),
                      ),
                      const SizedBox(height: 16),
                      CustomFormWidgets.buildDropdown<String>(
                        label: 'Time Slot',
                        icon: Icons.access_time,
                        value: _timeSlot,
                        items: _timeSlotOptions.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(),
                        onChanged: (val) => setState(() => _timeSlot = val),
                      ),
                      
                      const SizedBox(height: 32),
                      CustomFormWidgets.buildSectionHeader('Settings', Icons.settings_outlined),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SwitchListTile(
                          title: const Text('Batch is Active', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: const Text('Inactive batches are skipped or prorated during fee generation.', style: TextStyle(fontSize: 12)),
                          value: _isActive,
                          activeThumbColor: CustomFormWidgets.primaryColor,
                          onChanged: (val) async {
                            if (widget.batch != null) {
                              if (!val) {
                                // Toggling to inactive
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                  helpText: 'Select Inactive Start Date',
                                );
                                if (picked != null) {
                                  setState(() {
                                    _isActive = false;
                                    _inactiveStartDate = picked;
                                    _activationDate = null;
                                  });
                                }
                              } else {
                                // Toggling to active
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                  helpText: 'Select Activation Date',
                                );
                                if (picked != null) {
                                  setState(() {
                                    _isActive = true;
                                    _activationDate = picked;
                                    _inactiveStartDate = null;
                                  });
                                }
                              }
                            } else {
                              setState(() => _isActive = val);
                            }
                          },
                        ),
                      ),
                      if (_inactiveStartDate != null) ...[
                        const SizedBox(height: 8),
                        Text('Inactive Start: ${_inactiveStartDate!.toLocal().toString().split(' ')[0]}', style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                      if (_activationDate != null) ...[
                        const SizedBox(height: 8),
                        Text('Activation Date: ${_activationDate!.toLocal().toString().split(' ')[0]}', style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            CustomFormWidgets.buildBottomBar(
              context: context,
              onCancel: () => Navigator.pop(context),
              onSave: _save,
              saveLabel: widget.batch == null ? 'Save Batch' : 'Update Batch',
            ),
          ],
        ),
      ),
    );
  }
}
