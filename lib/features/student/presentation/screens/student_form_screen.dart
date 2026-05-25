import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';


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
  late TextEditingController _rollCtrl;
  String? _selectedClass;
  final List<String> _availableClasses = [
    'Class 6', 'Class 7', 'Class 8', 'Class 9', 
    'Class 10', 'Class 11', 'Class 12',
    'Admission', 'Job Prep', 'Other'
  ];
  late TextEditingController _addressCtrl;
  late TextEditingController _notesCtrl;
  late DateTime _createdAt;

  @override
  void initState() {
    super.initState();
    final s = widget.student;
    _nameCtrl = TextEditingController(text: s?.name ?? '');
    _phoneCtrl = TextEditingController(text: s?.phone ?? '');
    _gNameCtrl = TextEditingController(text: s?.guardianName ?? '');
    _gPhoneCtrl = TextEditingController(text: s?.guardianPhone ?? '');
    _schoolCtrl = TextEditingController(text: s?.schoolCollege ?? '');
    _selectedClass = s?.className;
    if (_selectedClass != null && _selectedClass!.isNotEmpty && !_availableClasses.contains(_selectedClass)) {
      _availableClasses.add(_selectedClass!);
    }
    _rollCtrl = TextEditingController(text: s?.rollNumber?.toString() ?? '');
    _addressCtrl = TextEditingController(text: s?.address ?? '');
    _notesCtrl = TextEditingController(text: s?.notes ?? '');
    _createdAt = s?.createdAt ?? DateTime.now();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _gNameCtrl.dispose();
    _gPhoneCtrl.dispose();
    _schoolCtrl.dispose();
    _rollCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
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
        schoolCollege: _schoolCtrl.text.trim(),
        className: _selectedClass,
        rollNumber: int.tryParse(_rollCtrl.text.trim()),
        address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        createdAt: _createdAt,
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
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4338CA),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.student == null ? 'Add New Student' : 'Edit Student', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const Text('Enter student information', style: TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined, color: Colors.white),
            onPressed: _save,
          )
        ],
        iconTheme: const IconThemeData(color: Colors.white),
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
                      _buildSectionHeader('Personal Information', Icons.person_outline),
                      const SizedBox(height: 20),
                      _buildTextField('Student Name *', 'Enter student full name', Icons.person_outline, _nameCtrl),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildTextField('Phone Number *', 'Enter phone number', Icons.phone_outlined, _phoneCtrl, keyboardType: TextInputType.phone, inputFormatters: [LengthLimitingTextInputFormatter(11)])),
                          const SizedBox(width: 16),
                          Expanded(child: _buildDatePicker('Admission Date *', _createdAt, (d) { setState(() => _createdAt = d); })),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildDropdownString('Class *', Icons.school_outlined, _selectedClass, _availableClasses, (val) => setState(() => _selectedClass = val))),
                          const SizedBox(width: 16),
                          Expanded(child: _buildTextField('Roll Number *', 'Enter roll number', Icons.tag, _rollCtrl, keyboardType: TextInputType.number)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildTextField('School / College Name', 'Enter school or college name', Icons.account_balance_outlined, _schoolCtrl, required: false),
                      const SizedBox(height: 32),

                      _buildSectionHeader('Guardian Information', Icons.people_outline),
                      const SizedBox(height: 20),
                      _buildTextField('Guardian Name *', 'Enter guardian full name', Icons.person_outline, _gNameCtrl),
                      const SizedBox(height: 16),
                      _buildTextField('Guardian Phone *', 'Enter guardian phone number', Icons.phone_outlined, _gPhoneCtrl, keyboardType: TextInputType.phone, inputFormatters: [LengthLimitingTextInputFormatter(11)]),

                      const SizedBox(height: 32),
                      _buildSectionHeader('Additional Information', Icons.info_outline),
                      const SizedBox(height: 20),
                      _buildTextField('Address', 'Enter full address', Icons.location_on_outlined, _addressCtrl, required: false),
                      const SizedBox(height: 16),
                      _buildTextField('Notes', 'Any additional notes', Icons.notes_outlined, _notesCtrl, required: false),
                    ],
                  ),
                ),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF4338CA), size: 20),
        ),
        const SizedBox(width: 12),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF4338CA))),
        const SizedBox(width: 16),
        Expanded(child: Divider(color: Colors.indigo.withValues(alpha: 0.1), thickness: 1)),
      ],
    );
  }

  Widget _buildTextField(String label, String hint, IconData icon, TextEditingController controller, {TextInputType keyboardType = TextInputType.text, bool required = true, List<TextInputFormatter>? inputFormatters}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF4338CA))),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: Icon(icon, color: Colors.grey.shade500, size: 20),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF4338CA))),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red)),
            focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red)),
          ),
          validator: required ? (val) {
            if (val == null || val.trim().isEmpty) return 'Required';
            if (label.contains('Phone')) {
              if (!RegExp(r'^01\d{9}$').hasMatch(val.trim())) return 'Invalid BD phone';
            }
            if (label.contains('Roll Number')) {
              if (int.tryParse(val.trim()) == null) return 'Must be a valid number';
            }
            return null;
          } : null,
        ),
      ],
    );
  }

  Widget _buildDatePicker(String label, DateTime date, Function(DateTime) onDateSelected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF4338CA))),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: Color(0xFF4338CA),
                      onPrimary: Colors.white,
                      onSurface: Colors.black,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (d != null) onDateSelected(d);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined, color: Colors.grey.shade500, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    date.toLocal().toString().split(' ')[0],
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ),
                Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade500, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownString(String label, IconData icon, String? value, List<String> items, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF4338CA))),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade500),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.grey.shade500, size: 20),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF4338CA))),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red)),
          ),
          items: items.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 14)))).toList(),
          onChanged: onChanged,
          validator: (val) => val == null || val.isEmpty ? 'Required' : null,
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4338CA),
                  side: const BorderSide(color: Color(0xFFE0E7FF), width: 1.5),
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined, size: 18),
                label: Text(widget.student == null ? 'Save Student' : 'Update Student', style: const TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: const Color(0xFF4338CA),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
