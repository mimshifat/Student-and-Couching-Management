import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/batch.dart';
import '../providers/batch_provider.dart';

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

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.batch?.name ?? '');
    _descCtrl = TextEditingController(text: widget.batch?.description ?? '');
    _feeCtrl = TextEditingController(text: widget.batch?.monthlyFee.toString() ?? '0.0');
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
        monthlyFee: double.tryParse(_feeCtrl.text.trim()) ?? 0.0,
        createdAt: widget.batch?.createdAt ?? DateTime.now(),
      );

      final provider = context.read<BatchProvider>();
      bool success;
      if (widget.batch == null) {
        success = await provider.addBatch(b);
      } else {
        success = await provider.updateBatch(b);
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
        title: Text(widget.batch == null ? 'Add Batch' : 'Edit Batch'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Batch Name *'),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'Description (Optional)'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _feeCtrl,
                decoration: const InputDecoration(labelText: 'Monthly Fee *', prefixText: '৳ '),
                keyboardType: TextInputType.number,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Required';
                  if (double.tryParse(val) == null) return 'Invalid number';
                  return null;
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  child: const Text('Save Batch'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
