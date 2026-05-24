import 'package:flutter/material.dart';
import 'package:provider/provider.dart';


import '../../domain/entities/student.dart';
import '../providers/student_provider.dart';
import '../../../batch/presentation/providers/batch_provider.dart';
import '../../../enrollment/presentation/providers/enrollment_provider.dart';
import '../../../enrollment/domain/entities/enrollment.dart';

class StudentFormScreen extends StatefulWidget {
  final Student? student;

  const StudentFormScreen({super.key, this.student});

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
  late TextEditingController _classCtrl;
  late TextEditingController _rollCtrl;
  int? _selectedBatchId;
  final DateTime _joinDate = DateTime.now();
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
    _classCtrl = TextEditingController(text: s?.className ?? '');
    _rollCtrl = TextEditingController(text: s?.rollNumber?.toString() ?? '');
    _createdAt = s?.createdAt ?? DateTime.now();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BatchProvider>().loadBatches();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _gNameCtrl.dispose();
    _gPhoneCtrl.dispose();
    _schoolCtrl.dispose();
    _classCtrl.dispose();
    _rollCtrl.dispose();
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
        className: _classCtrl.text.trim(),
        rollNumber: int.tryParse(_rollCtrl.text.trim()),
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
        if (widget.student == null && _selectedBatchId != null && newStudentId != null) {
          final enrollment = Enrollment(
            studentId: newStudentId,
            batchId: _selectedBatchId!,
            joinDate: _joinDate,
            createdAt: DateTime.now(),
          );
          await context.read<EnrollmentProvider>().enrollStudent(enrollment);
          if (!mounted) return;
        }
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
      appBar: AppBar(
        title: Text(widget.student == null ? 'Add Student' : 'Edit Student'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _save,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Student Name *'),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone Number *'),
                keyboardType: TextInputType.phone,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Required';
                  if (!RegExp(r'^01\d{9}$').hasMatch(val.trim())) {
                    return 'Enter a valid 11-digit BD phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Created At'),
                subtitle: Text(_createdAt.toLocal().toString().split(' ')[0]),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _createdAt,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (d != null && mounted) {
                    setState(() {
                      _createdAt = DateTime(d.year, d.month, d.day);
                    });
                  }
                },
              ),
              const Divider(),
              const Text('Academic Details', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _schoolCtrl,
                decoration: const InputDecoration(labelText: 'School/College *'),
                validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _classCtrl,
                      decoration: const InputDecoration(labelText: 'Class *'),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _rollCtrl,
                      decoration: const InputDecoration(labelText: 'Roll Number *'),
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Required';
                        if (int.tryParse(val.trim()) == null) return 'Must be a valid number';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const Text('Guardian Details', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _gNameCtrl,
                decoration: const InputDecoration(labelText: 'Guardian Name *'),
                validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _gPhoneCtrl,
                decoration: const InputDecoration(labelText: 'Guardian Phone *'),
                keyboardType: TextInputType.phone,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Required';
                  if (!RegExp(r'^01\d{9}$').hasMatch(val.trim())) {
                    return 'Enter a valid 11-digit BD phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              if (widget.student == null) ...[
                const Divider(),
                const Text('Quick Enrollment (Optional)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Consumer<BatchProvider>(
                  builder: (context, batchProvider, child) {
                    if (batchProvider.isLoading) return const CircularProgressIndicator();
                    if (batchProvider.batches.isEmpty) return const Text('No batches available.');
                    return DropdownButtonFormField<int>(
                      decoration: const InputDecoration(labelText: 'Select Batch'),
                      initialValue: _selectedBatchId,
                      items: [
                        const DropdownMenuItem<int>(value: null, child: Text('None')),
                        ...batchProvider.batches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))),
                      ],
                      onChanged: (val) => setState(() => _selectedBatchId = val),
                    );
                  },
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  child: const Text('Save Student'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
