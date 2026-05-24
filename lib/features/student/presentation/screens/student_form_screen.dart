import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
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
  late TextEditingController _feeCtrl;
  late TextEditingController _gRelationCtrl;

  String _studentType = 'Normal';
  String _status = AppConstants.statusRunning;

  int? _selectedBatchId;
  final DateTime _joinDate = DateTime.now();
  late TextEditingController _discountCtrl;

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
    _feeCtrl = TextEditingController(text: s?.monthlyFee.toString() ?? '');
    _gRelationCtrl = TextEditingController(text: s?.guardianRelation ?? '');
    _discountCtrl = TextEditingController(text: '0.0');
    
    if (s != null) {
      _studentType = s.studentType;
      _status = s.status;
    }

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
    _feeCtrl.dispose();
    _gRelationCtrl.dispose();
    _discountCtrl.dispose();
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
        guardianRelation: _gRelationCtrl.text.trim(),
        schoolCollege: _schoolCtrl.text.trim(),
        className: _classCtrl.text.trim(),
        rollNumber: int.tryParse(_rollCtrl.text.trim()),
        studentType: _studentType,
        monthlyFee: _studentType == 'Private' ? (double.tryParse(_feeCtrl.text.trim()) ?? 0.0) : 0.0,
        status: _status,
        createdAt: widget.student?.createdAt ?? DateTime.now(),
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
            discountAmount: double.tryParse(_discountCtrl.text.trim()) ?? 0.0,
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
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _studentType,
                      decoration: const InputDecoration(labelText: 'Student Type *'),
                      items: const [
                        DropdownMenuItem(value: 'Normal', child: Text('Normal (Batch)')),
                        DropdownMenuItem(value: 'Private', child: Text('Private / Fallback')),
                      ],
                      onChanged: (val) => setState(() => _studentType = val!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: const InputDecoration(labelText: 'Status *'),
                      items: AppConstants.studentStatuses
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (val) => setState(() => _status = val!),
                    ),
                  ),
                ],
              ),
              if (_studentType == 'Private') ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _feeCtrl,
                  decoration: const InputDecoration(labelText: 'Private/Fallback Monthly Fee *', prefixText: '৳ '),
                  keyboardType: TextInputType.number,
                  validator: (val) {
                    if (_studentType == 'Private' && (val == null || val.isEmpty)) return 'Required';
                    if (_studentType == 'Private' && double.tryParse(val!) == null) return 'Invalid number';
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 16),
              const Divider(),
              const Text('Academic Details', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _schoolCtrl,
                decoration: const InputDecoration(labelText: 'School/College'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _classCtrl,
                      decoration: const InputDecoration(labelText: 'Class'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _rollCtrl,
                      decoration: const InputDecoration(labelText: 'Roll Number'),
                      keyboardType: TextInputType.number,
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
                decoration: const InputDecoration(labelText: 'Guardian Name'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _gRelationCtrl,
                decoration: const InputDecoration(labelText: 'Relation with Guardian'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _gPhoneCtrl,
                decoration: const InputDecoration(labelText: 'Guardian Phone'),
                keyboardType: TextInputType.phone,
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
                const SizedBox(height: 16),
                if (_selectedBatchId != null)
                  TextFormField(
                    controller: _discountCtrl,
                    decoration: const InputDecoration(labelText: 'Discount Amount', prefixText: '৳ '),
                    keyboardType: TextInputType.number,
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
