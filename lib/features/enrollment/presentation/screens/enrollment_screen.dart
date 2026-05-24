import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/enrollment.dart';
import '../providers/enrollment_provider.dart';
import '../../../batch/presentation/providers/batch_provider.dart';

class EnrollmentScreen extends StatefulWidget {
  final int studentId;

  const EnrollmentScreen({super.key, required this.studentId});

  @override
  State<EnrollmentScreen> createState() => _EnrollmentScreenState();
}

class _EnrollmentScreenState extends State<EnrollmentScreen> {
  int? _selectedBatchId;
  DateTime _joinDate = DateTime.now();
  late TextEditingController _discountCtrl;

  @override
  void initState() {
    super.initState();
    _discountCtrl = TextEditingController(text: '0.0');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BatchProvider>().loadBatches();
    });
  }

  @override
  void dispose() {
    _discountCtrl.dispose();
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

    final enrollment = Enrollment(
      studentId: widget.studentId,
      batchId: _selectedBatchId!,
      joinDate: _joinDate,
      discountAmount: double.tryParse(_discountCtrl.text.trim()) ?? 0.0,
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
      appBar: AppBar(
        title: const Text('Enroll in Batch'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Consumer<BatchProvider>(
                builder: (context, batchProvider, child) {
                  if (batchProvider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (batchProvider.batches.isEmpty) {
                    return const Text('No batches available. Please create a batch first.');
                  }
                  return DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'Select Batch *'),
                    initialValue: _selectedBatchId,
                    items: batchProvider.batches.map((b) {
                      return DropdownMenuItem<int>(
                        value: b.id,
                        child: Text(b.name),
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
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Join Date *'),
                subtitle: Text(DateFormat('dd MMM yyyy').format(_joinDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDate,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _discountCtrl,
                decoration: const InputDecoration(labelText: 'Discount Amount', prefixText: '৳ '),
                keyboardType: TextInputType.number,
                validator: (val) {
                  if (val != null && val.isNotEmpty && double.tryParse(val) == null) {
                    return 'Invalid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  child: const Text('Enroll'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
