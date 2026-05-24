import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/student.dart';
import '../providers/student_provider.dart';

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

  DateTime _admissionDate = DateTime.now();
  String _status = AppConstants.statusRunning;

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
    
    if (s != null) {
      _admissionDate = s.admissionDate;
      _status = s.status;
    }
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
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _admissionDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _admissionDate = picked;
      });
    }
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
        admissionDate: _admissionDate,
        monthlyFee: double.tryParse(_feeCtrl.text.trim()) ?? 0.0,
        status: _status,
        createdAt: widget.student?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final provider = context.read<StudentProvider>();
      bool success;
      if (widget.student == null) {
        success = await provider.addStudent(s);
      } else {
        success = await provider.updateStudent(s);
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
                    child: TextFormField(
                      controller: _feeCtrl,
                      decoration: const InputDecoration(labelText: 'Private/Fallback Monthly Fee *', prefixText: '৳ '),
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Required';
                        if (double.tryParse(val) == null) return 'Invalid number';
                        return null;
                      },
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
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Admission Date *'),
                subtitle: Text(DateFormat('dd MMM yyyy').format(_admissionDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDate,
              ),
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
                controller: _gPhoneCtrl,
                decoration: const InputDecoration(labelText: 'Guardian Phone'),
                keyboardType: TextInputType.phone,
              ),
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
