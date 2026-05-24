import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/exam.dart';
import '../providers/exam_provider.dart';
import '../../../batch/presentation/providers/batch_provider.dart';

class ExamFormScreen extends StatefulWidget {
  final Exam? exam;

  const ExamFormScreen({super.key, this.exam});

  @override
  State<ExamFormScreen> createState() => _ExamFormScreenState();
}

class _ExamFormScreenState extends State<ExamFormScreen> {
  final _formKey = GlobalKey<FormState>();
  int? _selectedBatchId;
  late TextEditingController _titleCtrl;
  late TextEditingController _marksCtrl;
  DateTime _examDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final e = widget.exam;
    _selectedBatchId = e?.batchId;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _marksCtrl = TextEditingController(text: e?.totalMarks.toString() ?? '100');
    if (e != null) {
      _examDate = e.examDate;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BatchProvider>().loadBatches();
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _marksCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _examDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _examDate = picked;
      });
    }
  }

  void _save() async {
    if (_selectedBatchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a batch')),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      final e = Exam(
        id: widget.exam?.id,
        batchId: _selectedBatchId!,
        title: _titleCtrl.text.trim(),
        examDate: _examDate,
        totalMarks: double.tryParse(_marksCtrl.text.trim()) ?? 100.0,
        createdAt: widget.exam?.createdAt ?? DateTime.now(),
      );

      final provider = context.read<ExamProvider>();
      bool success;
      if (widget.exam == null) {
        success = await provider.addExam(e);
      } else {
        success = await provider.updateExam(e);
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
        title: Text(widget.exam == null ? 'Create Exam' : 'Edit Exam'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
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
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Exam Title *'),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _marksCtrl,
                decoration: const InputDecoration(labelText: 'Total Marks *'),
                keyboardType: TextInputType.number,
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Exam Date *'),
                subtitle: Text(DateFormat('dd MMM yyyy').format(_examDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDate,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  child: Text(widget.exam == null ? 'Create Exam' : 'Save Exam'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
