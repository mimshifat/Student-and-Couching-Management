import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';


import '../../domain/entities/student.dart';
import '../providers/student_provider.dart';
import '../../../enrollment/domain/entities/enrollment.dart';
import '../../../enrollment/presentation/providers/enrollment_provider.dart';
import '../../../../core/widgets/custom_form_widgets.dart';

class StudentFormScreen extends StatefulWidget {
  final Student? student;
  final int? initialBatchId;

  const StudentFormScreen({super.key, this.student, this.initialBatchId});

  @override
  State<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends State<StudentFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _gNameCtrl;
  late TextEditingController _gPhoneCtrl;
  late TextEditingController _schoolCtrl;
  late TextEditingController _rollCtrl;
  String? _selectedClass;
  final List<String> _availableClasses = [
    'Class 6', 'Class 7', 'Class 8', 'Class 9', 
    'Class 10', 'Class 11', 'Class 12',
    'Admission', 'Job Prep', 'Other'
  ];
  late TextEditingController _addressCtrl;
  late TextEditingController _notesCtrl;
  late DateTime _createdAt;

  @override
  void initState() {
    super.initState();
    final s = widget.student;
    _nameCtrl = TextEditingController(text: s?.name ?? '');
    _phoneCtrl = TextEditingController(text: s?.phone ?? '');
    _gNameCtrl = TextEditingController(text: s?.guardianName ?? '');
    _gPhoneCtrl = TextEditingController(text: s?.guardianPhone ?? '');
    _schoolCtrl = TextEditingController(text: s?.schoolCollege ?? '');
    _selectedClass = s?.className;
    if (_selectedClass != null && _selectedClass!.isNotEmpty && !_availableClasses.contains(_selectedClass)) {
      _availableClasses.add(_selectedClass!);
    }
    _rollCtrl = TextEditingController(text: s?.rollNumber?.toString() ?? '');
    _addressCtrl = TextEditingController(text: s?.address ?? '');
    _notesCtrl = TextEditingController(text: s?.notes ?? '');
    _createdAt = s?.createdAt ?? DateTime.now();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _gNameCtrl.dispose();
    _gPhoneCtrl.dispose();
    _schoolCtrl.dispose();
    _rollCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _save() async {
    if (_formKey.currentState!.validate()) {
      final s = Student(
        id: widget.student?.id,
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        guardianName: _gNameCtrl.text.trim(),
        guardianPhone: _gPhoneCtrl.text.trim(),
        schoolCollege: _schoolCtrl.text.trim(),
        className: _selectedClass,
        rollNumber: int.tryParse(_rollCtrl.text.trim()),
        address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        createdAt: _createdAt,
        updatedAt: DateTime.now(),
      );

      final provider = context.read<StudentProvider>();
      int? newStudentId;
      bool success = false;
      if (widget.student == null) {
        newStudentId = await provider.addStudent(s);
        success = newStudentId != null;
      } else {
        success = await provider.updateStudent(s);
        newStudentId = s.id;
      }

      if (success && mounted) {
        if (widget.initialBatchId != null && widget.student == null && newStudentId != null) {
          final enrollment = Enrollment(
            studentId: newStudentId,
            batchId: widget.initialBatchId!,
            joinDate: DateTime.now(),
            createdAt: DateTime.now(),
          );
          await context.read<EnrollmentProvider>().enrollStudent(enrollment);
        }
        if (!mounted) return;
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
        title: widget.student == null ? 'Add New Student' : 'Edit Student',
        subtitle: 'Enter student information',
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
                      CustomFormWidgets.buildSectionHeader('Personal Information', Icons.person_outline),
                      const SizedBox(height: 20),
                      CustomFormWidgets.buildTextField(
                        label: 'Student Name *',
                        hint: 'Enter student full name',
                        icon: Icons.person_outline,
                        controller: _nameCtrl,
                        validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: CustomFormWidgets.buildTextField(
                              label: 'Phone Number *',
                              hint: 'Enter phone number',
                              icon: Icons.phone_outlined,
                              controller: _phoneCtrl,
                              isNumber: true,
                              inputFormatters: [LengthLimitingTextInputFormatter(11)],
                              validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: CustomFormWidgets.buildDatePicker(
                              context: context,
                              label: 'Admission Date *',
                              date: _createdAt,
                              onTap: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: _createdAt,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (d != null) setState(() => _createdAt = d);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: CustomFormWidgets.buildDropdown<String>(
                              label: 'Class *',
                              icon: Icons.school_outlined,
                              value: _selectedClass,
                              items: _availableClasses.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 14)))).toList(),
                              onChanged: (val) => setState(() => _selectedClass = val),
                              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: CustomFormWidgets.buildTextField(
                              label: 'Roll Number *',
                              hint: 'Enter roll number',
                              icon: Icons.tag,
                              controller: _rollCtrl,
                              isNumber: true,
                              validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      CustomFormWidgets.buildTextField(
                        label: 'School / College Name',
                        hint: 'Enter school or college name',
                        icon: Icons.account_balance_outlined,
                        controller: _schoolCtrl,
                      ),
                      const SizedBox(height: 32),

                      CustomFormWidgets.buildSectionHeader('Guardian Information', Icons.people_outline),
                      const SizedBox(height: 20),
                      CustomFormWidgets.buildTextField(
                        label: 'Guardian Name *',
                        hint: 'Enter guardian full name',
                        icon: Icons.person_outline,
                        controller: _gNameCtrl,
                        validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      CustomFormWidgets.buildTextField(
                        label: 'Guardian Phone *',
                        hint: 'Enter guardian phone number',
                        icon: Icons.phone_outlined,
                        controller: _gPhoneCtrl,
                        isNumber: true,
                        inputFormatters: [LengthLimitingTextInputFormatter(11)],
                        validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                      ),

                      const SizedBox(height: 32),
                      CustomFormWidgets.buildSectionHeader('Additional Information', Icons.info_outline),
                      const SizedBox(height: 20),
                      CustomFormWidgets.buildTextField(
                        label: 'Address',
                        hint: 'Enter full address',
                        icon: Icons.location_on_outlined,
                        controller: _addressCtrl,
                      ),
                      const SizedBox(height: 16),
                      CustomFormWidgets.buildTextField(
                        label: 'Notes',
                        hint: 'Any additional notes',
                        icon: Icons.notes_outlined,
                        controller: _notesCtrl,
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
              saveLabel: widget.student == null ? 'Save Student' : 'Update Student',
            ),
          ],
        ),
      ),
    );
  }
}
