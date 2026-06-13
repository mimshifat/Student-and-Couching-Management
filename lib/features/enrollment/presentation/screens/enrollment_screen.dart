import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/enrollment.dart';
import '../providers/enrollment_provider.dart';
import '../../../batch/presentation/providers/batch_provider.dart';
import '../../../fee/presentation/providers/fee_provider.dart';
import '../../../../core/widgets/custom_form_widgets.dart';

class EnrollmentScreen extends StatefulWidget {
  final int studentId;

  const EnrollmentScreen({super.key, required this.studentId});

  @override
  State<EnrollmentScreen> createState() => _EnrollmentScreenState();
}

class _EnrollmentScreenState extends State<EnrollmentScreen> {
  int? _selectedBatchId;
  DateTime _joinDate = DateTime.now();
  final TextEditingController _customFeeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BatchProvider>().loadBatches();
    });
  }

  @override
  void dispose() {
    _customFeeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _joinDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _joinDate = picked;
      });
    }
  }

  final _formKey = GlobalKey<FormState>();

  void _save() async {
    if (_selectedBatchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a batch')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final feeText = _customFeeCtrl.text.trim();
    final double? feeOverride = feeText.isNotEmpty ? double.tryParse(feeText) : null;

    final enrollment = Enrollment(
      studentId: widget.studentId,
      batchId: _selectedBatchId!,
      joinDate: _joinDate,
      feeOverride: feeOverride,
      createdAt: DateTime.now(),
    );

    final provider = context.read<EnrollmentProvider>();
    final success = await provider.enrollStudent(enrollment);

    if (success && mounted) {
      // Generate fee records for this student immediately in the same session.
      // Without this, fees only appear after the next app launch.
      final currentYear = DateTime.now().year;
      await context.read<FeeProvider>().loadPendingFeeRecords(
        forceRegenerate: true,
        year: currentYear,
      );
      if (mounted) Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.errorMessage ?? 'An error occurred')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CustomFormWidgets.backgroundColor,
      appBar: CustomFormWidgets.buildAppBar(
        title: 'Enroll in Batch',
        subtitle: 'Add student to a new batch',
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
                      CustomFormWidgets.buildSectionHeader('Enrollment Details', Icons.school_outlined),
                      const SizedBox(height: 20),
                      Consumer2<BatchProvider, EnrollmentProvider>(
                        builder: (context, batchProvider, enrollmentProvider, child) {
                          if (batchProvider.isLoading) {
                            return const Center(child: CircularProgressIndicator());
                          }
        
                          // Find batches the student is already actively enrolled in
                          final activeBatchIds = enrollmentProvider.activeEnrollments
                              .where((e) => e.studentId == widget.studentId)
                              .map((e) => e.batchId)
                              .toSet();
        
                          // Filter them out
                          final availableBatches = batchProvider.batches
                              .where((b) => !activeBatchIds.contains(b.id))
                              .toList();
        
                          if (batchProvider.batches.isEmpty) {
                            return const Text('No batches available. Please create a batch first.', style: TextStyle(color: Colors.black54));
                          }
                          
                          if (availableBatches.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16.0),
                              child: Text(
                                'This student is already enrolled in all available batches.',
                                style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                              ),
                            );
                          }
        
                          return CustomFormWidgets.buildDropdown<int>(
                            label: 'Select Batch *',
                            icon: Icons.class_outlined,
                            value: _selectedBatchId,
                            items: availableBatches.map((b) {
                              return DropdownMenuItem<int>(
                                value: b.id,
                                child: Text(b.name, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedBatchId = val;
                              });
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      CustomFormWidgets.buildDatePicker(
                        context: context,
                        label: 'Join Date *',
                        date: _joinDate,
                        onTap: _pickDate,
                      ),
                      const SizedBox(height: 32),
                      CustomFormWidgets.buildSectionHeader('Custom Settings', Icons.settings_outlined),
                      const SizedBox(height: 20),
                      CustomFormWidgets.buildTextField(
                        label: 'Custom Monthly Fee (Optional)',
                        hint: 'Leave empty for default batch fee',
                        prefixText: '৳ ',
                        controller: _customFeeCtrl,
                        isNumber: true,
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
              saveLabel: 'Enroll Student',
            ),
          ],
        ),
      ),
    );
  }
}
