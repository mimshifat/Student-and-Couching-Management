import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/fee_record.dart';
import '../providers/fee_provider.dart';
import '../../../student/presentation/providers/student_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../../core/widgets/custom_form_widgets.dart';
import '../../../../core/services/sms_service.dart';

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
  late TextEditingController _studentNameCtrl;
  late TextEditingController _batchNameCtrl;
  late bool _isSettled;
  String _smsMode = SmsService.modeDefaultApp;
  bool _sendSmsConfirmation = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    double remaining = widget.feeRecord.totalAmount - widget.feeRecord.paidAmount;
    if (remaining < 0) remaining = 0;
    _amountCtrl = TextEditingController(text: remaining > 0 ? remaining.toStringAsFixed(0) : '');
    
    final studentIdx = context.read<StudentProvider>().students.indexWhere((s) => s.id == widget.studentId);
    final className = studentIdx >= 0 ? context.read<StudentProvider>().students[studentIdx].className ?? 'Unknown Class' : 'Unknown Class';
    final cleanBatch = SmsService.cleanBatchName(widget.feeRecord.batchDetailsSnapshot);
    final batchName = cleanBatch.isNotEmpty ? cleanBatch : (widget.feeRecord.batchDetailsSnapshot ?? 'Unknown Batch');
    
    _studentNameCtrl = TextEditingController(text: '${widget.studentName} ($className)');
    _batchNameCtrl = TextEditingController(text: batchName);
    
    _isSettled = widget.feeRecord.isSettled;

    // Load SMS mode configuration safely
    SmsService.getSmsMode().then((mode) {
      if (mounted) {
        setState(() {
          _smsMode = mode;
        });
      }
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _studentNameCtrl.dispose();
    _batchNameCtrl.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_isSaving) return;

    if (_formKey.currentState!.validate()) {
      final newPayment = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
      
      // Allow 0 if they just want to mark as settled or add a note
      if (newPayment == 0 && !_isSettled && widget.feeRecord.paidAmount == 0 && _noteCtrl.text.trim().isEmpty) return;

      if (newPayment < 0) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirm Negative Payment'),
            content: Text('You are entering a negative payment (৳${newPayment.toStringAsFixed(0)}). This will reduce the student\'s total paid amount. Are you sure you want to proceed with this correction?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Proceed', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        if (confirm != true) return;
      }

      await _processPayment(newPayment);
    }
  }

  Future<void> _processPayment(double newPayment) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final provider = context.read<FeeProvider>();
      final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
      final success = await provider.addPayment(widget.feeRecord.id!, newPayment, widget.studentId, isSettled: _isSettled, note: note);
      
      if (success && mounted) {
        String? smsFeedback;
        if (newPayment > 0 && _sendSmsConfirmation && _smsMode != SmsService.modeNoSms) {
          final students = context.read<StudentProvider>().students;
          final profile = context.read<ProfileProvider>().profile;
          final shortName = profile?.instituteShortName ?? profile?.instituteName ?? 'Institute';
          final ownerName = profile?.ownerName ?? 'Admin';
          final studentIdx = students.indexWhere((s) => s.id == widget.studentId);
          if (studentIdx >= 0) {
            final student = students[studentIdx];
            if (student.phone != null && student.phone!.trim().isNotEmpty) {
              final monthName = DateFormat('MMMM').format(DateTime(widget.feeRecord.year, widget.feeRecord.month));
              final batchPart = SmsService.formatBatchPart(widget.feeRecord.batchDetailsSnapshot);
              final message = '[$shortName]\nDear ${student.name}, your fee payment of Tk. ${newPayment.toStringAsFixed(0)} for $monthName ${widget.feeRecord.year}$batchPart has been received. Thank you!\n-$ownerName';
              
              final smsResult = await SmsService.sendSms(
                phone: student.phone!,
                message: message,
                overrideMode: _smsMode,
              );

              if (!smsResult.success) {
                smsFeedback = 'Could not send SMS: ${smsResult.message ?? 'Unknown error'}';
              } else if (_smsMode == SmsService.modeAutoSim1) {
                smsFeedback = 'Confirmation SMS sent via SIM 1.';
              } else if (_smsMode == SmsService.modeAutoSim2) {
                smsFeedback = 'Confirmation SMS sent via SIM 2.';
              }
            } else {
              smsFeedback = 'No phone number saved for this student.';
            }
          }
        }

        if (mounted) {
          final snackMsg = smsFeedback != null
              ? 'Payment recorded. $smsFeedback'
              : 'Payment recorded successfully.';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(snackMsg),
            backgroundColor: smsFeedback != null && smsFeedback.startsWith('Could not send SMS')
                ? Colors.orange
                : const Color(0xFF2B9348),
          ));
          Navigator.pop(context);
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.errorMessage ?? 'Error saving payment')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment error: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM yyyy').format(DateTime(widget.feeRecord.year, widget.feeRecord.month));

    return PopScope(
      canPop: !_isSaving,
      child: Scaffold(
        backgroundColor: CustomFormWidgets.backgroundColor,
        appBar: CustomFormWidgets.buildAppBar(
          title: 'Add Payment',
          subtitle: 'Record fee payment for student',
          onSave: _isSaving ? null : _submit,
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
                          controller: _studentNameCtrl,
                          icon: Icons.person,
                          readOnly: true,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),
                        CustomFormWidgets.buildTextField(
                          label: 'Batch',
                          controller: _batchNameCtrl,
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
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
                          ],
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Required';
                            if (double.tryParse(val.trim()) == null) return 'Invalid amount';
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
                            onChanged: _isSaving ? null : (val) {
                              setState(() => _isSettled = val ?? false);
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                        ),
                        if (_smsMode != SmsService.modeNoSms) ...[
                          const SizedBox(height: 16),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade200),
                              borderRadius: BorderRadius.circular(12),
                              color: _sendSmsConfirmation ? const Color(0xFFF0F7FF) : Colors.white,
                            ),
                            child: CheckboxListTile(
                              title: Row(
                                children: [
                                  const Text('Send SMS Confirmation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _getSmsBadgeColor(_smsMode).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _getSmsModeLabel(_smsMode),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: _getSmsBadgeColor(_smsMode),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                _getSmsSubtitle(_smsMode),
                                style: const TextStyle(fontSize: 11, color: Colors.black54),
                              ),
                              value: _sendSmsConfirmation,
                              activeColor: const Color(0xFF1D3557),
                              onChanged: _isSaving ? null : (val) {
                                setState(() => _sendSmsConfirmation = val ?? false);
                              },
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              CustomFormWidgets.buildBottomBar(
                context: context,
                onCancel: _isSaving ? () {} : () => Navigator.pop(context),
                saveLabel: _isSaving ? 'Processing...' : 'Save Payment',
                onSave: _isSaving ? () {} : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getSmsModeLabel(String mode) {
    if (mode == SmsService.modeAutoSim1) return 'Auto SIM 1';
    if (mode == SmsService.modeAutoSim2) return 'Auto SIM 2';
    return 'Default App';
  }

  Color _getSmsBadgeColor(String mode) {
    if (mode == SmsService.modeAutoSim1 || mode == SmsService.modeAutoSim2) {
      return const Color(0xFF2B9348);
    }
    return const Color(0xFF1D3557);
  }

  String _getSmsSubtitle(String mode) {
    if (mode == SmsService.modeAutoSim1) {
      return 'Confirmation SMS will be sent automatically via SIM 1.';
    }
    if (mode == SmsService.modeAutoSim2) {
      return 'Confirmation SMS will be sent automatically via SIM 2.';
    }
    return 'Opens your messaging app to send confirmation manually.';
  }
}
