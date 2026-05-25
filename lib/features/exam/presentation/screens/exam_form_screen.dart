import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/exam.dart';
import '../providers/exam_provider.dart';
import '../../../batch/presentation/providers/batch_provider.dart';
import '../../../../core/widgets/custom_form_widgets.dart';

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
  String _selectedExamType = 'Monthly';

  final List<String> _examTypes = [
    'Weekly', 'Monthly', 'Test', 'Model Test', 'Final', 'Other'
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.exam;
    _selectedBatchId = e?.batchId;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _marksCtrl = TextEditingController(text: e?.totalMarks.toString() ?? '100.0');
    if (e != null) {
      _examDate = e.examDate;
      _selectedExamType = _examTypes.contains(e.examType) ? e.examType : 'Other';
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
        examType: _selectedExamType,
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
      backgroundColor: CustomFormWidgets.backgroundColor,
      appBar: CustomFormWidgets.buildAppBar(
        title: widget.exam == null ? 'Create Exam' : 'Edit Exam',
        subtitle: 'Enter exam details',
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
                      CustomFormWidgets.buildSectionHeader('Exam Information', Icons.assignment_outlined),
                      const SizedBox(height: 16),
                      Consumer<BatchProvider>(
                        builder: (context, batchProvider, child) {
                          if (batchProvider.isLoading) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (batchProvider.batches.isEmpty) {
                            return const Text('No batches available. Please create a batch first.');
                          }
                          return CustomFormWidgets.buildDropdown<int>(
                            label: 'Select Batch *',
                            icon: Icons.class_outlined,
                            value: _selectedBatchId,
                            items: batchProvider.batches.map((b) {
                              return DropdownMenuItem<int>(
                                value: b.id,
                                child: Text(b.name, style: const TextStyle(fontSize: 14)),
                              );
                            }).toList(),
                            onChanged: (val) => setState(() => _selectedBatchId = val),
                            validator: (val) => val == null ? 'Required' : null,
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      CustomFormWidgets.buildTextField(
                        label: 'Exam Title *',
                        hint: 'Enter exam title (e.g., Weekly Math Test)',
                        icon: Icons.title_outlined,
                        controller: _titleCtrl,
                        validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: CustomFormWidgets.buildDropdown<String>(
                              label: 'Exam Type *',
                              icon: Icons.category_outlined,
                              value: _selectedExamType,
                              items: _examTypes.map((t) {
                                return DropdownMenuItem<String>(
                                  value: t,
                                  child: Text(t, style: const TextStyle(fontSize: 14)),
                                );
                              }).toList(),
                              onChanged: (val) => setState(() => _selectedExamType = val!),
                              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CustomFormWidgets.buildTextField(
                              label: 'Total Marks *',
                              hint: 'Enter total marks',
                              icon: Icons.score_outlined,
                              controller: _marksCtrl,
                              isNumber: true,
                              validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      CustomFormWidgets.buildDatePicker(
                        context: context,
                        label: 'Exam Date *',
                        date: _examDate,
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _examDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (d != null) setState(() => _examDate = d);
                        },
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
              saveLabel: widget.exam == null ? 'Save Exam' : 'Update Exam',
            ),
          ],
        ),
      ),
    );
  }
}
