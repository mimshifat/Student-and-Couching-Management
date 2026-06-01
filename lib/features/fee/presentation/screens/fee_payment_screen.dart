import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/fee_record.dart';
import '../providers/fee_provider.dart';
import '../../../student/presentation/providers/student_provider.dart';
import '../../../../core/widgets/custom_form_widgets.dart';
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
  late bool _isSettled;

  @override
  void initState() {
    super.initState();
    double remaining = widget.feeRecord.totalAmount - widget.feeRecord.paidAmount;
    if (remaining < 0) remaining = 0;
    _amountCtrl = TextEditingController(text: remaining > 0 ? remaining.toStringAsFixed(0) : '');
    _isSettled = widget.feeRecord.isSettled;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      final newPayment = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
      
      // Allow 0 if they just want to mark as settled or add a note
      if (newPayment == 0 && !_isSettled && widget.feeRecord.paidAmount == 0 && _noteCtrl.text.trim().isEmpty) return;

      final totalPaid = widget.feeRecord.paidAmount + newPayment;

      final provider = context.read<FeeProvider>();
      final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
      final success = await provider.updatePaidAmount(widget.feeRecord.id!, totalPaid, widget.studentId, isSettled: _isSettled, note: note);
      
      if (success && mounted) {
        if (newPayment > 0) {
          final students = context.read<StudentProvider>().students;
          final studentIdx = students.indexWhere((s) => s.id == widget.studentId);
          if (studentIdx >= 0) {
            final student = students[studentIdx];
            if (student.phone != null && student.phone!.isNotEmpty) {
              final monthName = DateFormat('MMMM').format(DateTime(widget.feeRecord.year, widget.feeRecord.month));
              final message = '[CSA]\nDear ${student.name}, your fee payment of ${newPayment.toStringAsFixed(0)} TK for $monthName ${widget.feeRecord.year} has been received. Thank you!\n-Abdus Samad';
              final uri = Uri.parse('sms:${student.phone}?body=${Uri.encodeComponent(message)}');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            }
          }
        }
        
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
    final studentIdx = context.read<StudentProvider>().students.indexWhere((s) => s.id == widget.studentId);
    final className = studentIdx >= 0 ? context.read<StudentProvider>().students[studentIdx].className ?? 'Unknown Class' : 'Unknown Class';
    
    String batchName = widget.feeRecord.batchDetailsSnapshot ?? 'Unknown Batch';

    return Scaffold(
      backgroundColor: CustomFormWidgets.backgroundColor,
      appBar: CustomFormWidgets.buildAppBar(
        title: 'Add Payment',
        subtitle: 'Record fee payment for student',
        onSave: _submit,
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
                      CustomFormWidgets.buildSectionHeader('Student Details', Icons.person_outline),
                      const SizedBox(height: 20),
                      CustomFormWidgets.buildTextField(
                        label: 'Student',
                        controller: TextEditingController(text: '${widget.studentName} ($className)'),
                        icon: Icons.person,
                        readOnly: true,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      CustomFormWidgets.buildTextField(
                        label: 'Batch',
                        controller: TextEditingController(text: batchName),
                        icon: Icons.class_outlined,
                        readOnly: true,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      CustomFormWidgets.buildTextField(
                        label: 'Month',
                        controller: TextEditingController(text: monthName),
                        icon: Icons.calendar_today_outlined,
                        readOnly: true,
                      ),
                      
                      const SizedBox(height: 32),
                      CustomFormWidgets.buildSectionHeader('Payment Details', Icons.payment_outlined),
                      const SizedBox(height: 20),
                      
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text('Total Fee (Calculated)', style: TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w600)),
                                Text('৳ ${widget.feeRecord.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                              ],
                            ),
                            if (widget.feeRecord.paidAmount > 0) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Divider(height: 1, color: Colors.black12),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Text('Already Paid', style: TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w600)),
                                  Text('৳ ${widget.feeRecord.paidAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2B9348))),
                                ],
                              ),
                            ]
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      CustomFormWidgets.buildTextField(
                        label: 'Amount to Pay Now *',
                        hint: 'Enter payment amount (use negative to correct)',
                        prefixText: '৳ ',
                        controller: _amountCtrl,
                        isNumber: true,
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Required';
                          if (double.tryParse(val) == null) return 'Invalid amount';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      CustomFormWidgets.buildTextField(
                        label: 'Note (Optional)',
                        hint: 'Write note here...',
                        icon: Icons.notes_outlined,
                        controller: _noteCtrl,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 20),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(12),
                          color: _isSettled ? const Color(0xFFE8F8EE) : Colors.white,
                        ),
                        child: CheckboxListTile(
                          title: const Text('Mark as Paid', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: const Text(
                            'Check this if the student has settled this month\'s fee, even if the paid amount is less than the total fee.',
                            style: TextStyle(fontSize: 11, color: Colors.black54),
                          ),
                          value: _isSettled,
                          activeColor: const Color(0xFF2B9348),
                          onChanged: (val) {
                            setState(() => _isSettled = val ?? false);
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            CustomFormWidgets.buildBottomBar(
              context: context,
              onCancel: () => Navigator.pop(context),
              onSave: _submit,
              saveLabel: 'Save Payment',
            ),
          ],
        ),
      ),
    );
  }
}
