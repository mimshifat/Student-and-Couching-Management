import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/payment.dart';
import '../../domain/entities/fee_record.dart';
import '../providers/fee_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';

class FeePaymentScreen extends StatefulWidget {
  final int studentId;
  final String studentName;
  final FeeRecord feeRecord;

  const FeePaymentScreen({super.key, required this.studentId, required this.studentName, required this.feeRecord});

  @override
  State<FeePaymentScreen> createState() => _FeePaymentScreenState();
}

class _FeePaymentScreenState extends State<FeePaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountCtrl;
  late TextEditingController _noteCtrl;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController();
    _noteCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
      if (amount <= 0) return;

      final payment = Payment(
        feeRecordId: widget.feeRecord.id!,
        studentId: widget.studentId,
        amount: amount,
        paymentDate: DateTime.now(),
        note: _noteCtrl.text.trim(),
        createdAt: DateTime.now(),
      );

      final provider = context.read<FeeProvider>();
      final success = await provider.makePayment(payment);
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment Recorded')));
        Navigator.pop(context);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.errorMessage ?? 'Error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM yyyy').format(DateTime(widget.feeRecord.year, widget.feeRecord.month));

    return Scaffold(
      appBar: AppBar(title: const Text('Record Payment')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.studentName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text('Month: $monthName', style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Total Fee: ৳${widget.feeRecord.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Already Paid: ৳${widget.feeRecord.paidAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, color: AppTheme.accentColor)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _amountCtrl,
                    decoration: const InputDecoration(labelText: 'Amount Paid *', prefixText: '৳ '),
                    keyboardType: TextInputType.number,
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Required';
                      if (double.tryParse(val) == null) return 'Invalid amount';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _noteCtrl,
                    decoration: const InputDecoration(labelText: 'Note (Optional)'),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.payment),
                      label: const Text('Save Payment'),
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
