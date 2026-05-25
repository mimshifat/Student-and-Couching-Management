import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/enrollment.dart';
import '../providers/enrollment_provider.dart';
import '../../../student/presentation/providers/student_provider.dart';
import '../../../../core/widgets/custom_form_widgets.dart';
import '../../../batch/domain/entities/batch.dart';

class BatchStudentEnrollmentScreen extends StatefulWidget {
  final Batch batch;

  const BatchStudentEnrollmentScreen({super.key, required this.batch});

  @override
  State<BatchStudentEnrollmentScreen> createState() => _BatchStudentEnrollmentScreenState();
}

class _BatchStudentEnrollmentScreenState extends State<BatchStudentEnrollmentScreen> {
  int? _selectedStudentId;
  DateTime _joinDate = DateTime.now();
  final TextEditingController _customFeeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudentProvider>().loadStudents();
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
    if (_selectedStudentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a student')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final feeText = _customFeeCtrl.text.trim();
    final double? feeOverride = feeText.isNotEmpty ? double.tryParse(feeText) : null;

    final enrollment = Enrollment(
      studentId: _selectedStudentId!,
      batchId: widget.batch.id!,
      joinDate: _joinDate,
      feeOverride: feeOverride,
      createdAt: DateTime.now(),
    );

    final provider = context.read<EnrollmentProvider>();
    final success = await provider.enrollStudent(enrollment);

    if (success && mounted) {
      Navigator.pop(context);
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
        title: 'Enroll Student',
        subtitle: 'Add a student to ${widget.batch.name}',
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
                      CustomFormWidgets.buildSectionHeader('Enrollment Details', Icons.person_add_alt_1_outlined),
                      const SizedBox(height: 20),
                      Consumer2<StudentProvider, EnrollmentProvider>(
                        builder: (context, studentProvider, enrollmentProvider, child) {
                          if (studentProvider.isLoading) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          
                          // Find students already in this batch
                          final activeStudentIdsInBatch = enrollmentProvider.activeEnrollments
                              .where((e) => e.batchId == widget.batch.id)
                              .map((e) => e.studentId)
                              .toSet();
                              
                          // Filter out students already in this batch
                          final availableStudents = studentProvider.students
                              .where((s) => !activeStudentIdsInBatch.contains(s.id))
                              .toList();

                          if (studentProvider.students.isEmpty) {
                            return const Text('No students available. Please add a student first.', style: TextStyle(color: Colors.black54));
                          }
                          
                          if (availableStudents.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16.0),
                              child: Text(
                                'All students are already enrolled in this batch.',
                                style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                              ),
                            );
                          }

                          return CustomFormWidgets.buildDropdown<int>(
                            label: 'Select Student *',
                            icon: Icons.person_outline,
                            value: _selectedStudentId,
                            items: availableStudents.map((s) {
                              return DropdownMenuItem<int>(
                                value: s.id,
                                child: Text('${s.name} (${s.phone ?? ''})', style: const TextStyle(fontSize: 14)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedStudentId = val;
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
