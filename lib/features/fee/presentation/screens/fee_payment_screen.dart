import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/fee_record.dart';
import '../providers/fee_provider.dart';
import '../../../batch/presentation/providers/batch_provider.dart';
import '../../../enrollment/presentation/providers/enrollment_provider.dart';
import '../../../student/presentation/providers/student_provider.dart';
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
  final TextEditingController _noteCtrl = TextEditingController();

  static const Color primaryNavy = Color(0xFF191A4E);

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(text: widget.feeRecord.paidAmount > 0 ? widget.feeRecord.paidAmount.toStringAsFixed(0) : '');
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

      final provider = context.read<FeeProvider>();
      final success = await provider.updatePaidAmount(widget.feeRecord.id!, amount, widget.studentId);
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment Recorded successfully.')));
        Navigator.pop(context);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.errorMessage ?? 'Error saving payment')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM yyyy').format(DateTime(widget.feeRecord.year, widget.feeRecord.month));

    // Try to get class name and batch name for UI perfection
    final student = context.read<StudentProvider>().students.firstWhere((s) => s.id == widget.studentId, orElse: () => throw Exception('Student not found'));
    final className = student.className ?? 'Unknown Class';
    
    final enrollment = context.read<EnrollmentProvider>().enrollments.where((e) => e.studentId == widget.studentId && e.leaveDate == null).firstOrNull;
    String batchName = 'Unknown Batch';
    if (enrollment != null) {
      final batch = context.read<BatchProvider>().batches.where((b) => b.id == enrollment.batchId).firstOrNull;
      if (batch != null) batchName = batch.name;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primaryNavy,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Add Payment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildReadOnlyField('Student', '${widget.studentName} ($className)', isDropdown: true),
            const SizedBox(height: 20),
            _buildReadOnlyField('Batch', batchName, isDropdown: true),
            const SizedBox(height: 20),
            _buildReadOnlyField('Month', monthName, isCalendar: true),
            const SizedBox(height: 24),
            
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Fee (Calculated)', style: TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text('৳ ${widget.feeRecord.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                    
                    const SizedBox(height: 24),
                    const Text('Paid Amount', style: TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _amountCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        prefixText: '৳ ',
                        prefixStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryNavy)),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Required';
                        if (double.tryParse(val) == null) return 'Invalid amount';
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),
                    const Text('Note (Optional)', style: TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _noteCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Write note here...',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryNavy)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryNavy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Save Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value, {bool isDropdown = false, bool isCalendar = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(value, style: const TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w500)),
              if (isDropdown) const Icon(Icons.keyboard_arrow_down, color: Colors.black54, size: 20),
              if (isCalendar) const Icon(Icons.calendar_today_outlined, color: Colors.black54, size: 20),
            ],
          ),
        ),
      ],
    );
  }
}
