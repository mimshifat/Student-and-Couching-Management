import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomFormWidgets {
  static const Color primaryColor = Color(0xFF4338CA);
  static const Color backgroundColor = Color(0xFFF9FAFB);

  static PreferredSizeWidget buildAppBar({required String title, required String subtitle, VoidCallback? onSave}) {
    return AppBar(
      backgroundColor: primaryColor,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ],
      ),
      actions: [
        if (onSave != null)
          IconButton(
            icon: const Icon(Icons.save_outlined, color: Colors.white),
            onPressed: onSave,
          ),
      ],
      iconTheme: const IconThemeData(color: Colors.white),
    );
  }

  static Widget buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: primaryColor, size: 20),
        ),
        const SizedBox(width: 12),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryColor)),
        const SizedBox(width: 16),
        Expanded(child: Divider(color: Colors.indigo.withValues(alpha: 0.1), thickness: 1)),
      ],
    );
  }

  static Widget buildTextField({
    required String label,
    String? hint,
    required TextEditingController controller,
    required IconData icon,
    bool isNumber = false,
    int maxLines = 1,
    String? Function(String?)? validator,
    String? prefixText,
    bool readOnly = false,
    VoidCallback? onTap,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: primaryColor)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          inputFormatters: inputFormatters ?? (isNumber ? [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))] : null),
          maxLines: maxLines,
          readOnly: readOnly,
          onTap: onTap,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: Icon(icon, color: Colors.grey.shade500, size: 20),
            prefixText: prefixText,
            prefixStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14),
            filled: true,
            fillColor: readOnly ? Colors.grey.shade50 : Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryColor)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red)),
          ),
          validator: validator,
        ),
      ],
    );
  }
  
  static Widget buildDatePicker({
    required BuildContext context,
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: primaryColor)),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
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

  static Widget buildTimePickerField({
    required BuildContext context,
    required String label,
    required TimeOfDay? time,
    required Function(TimeOfDay) onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: primaryColor)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: time ?? TimeOfDay.now(),
            );
            if (picked != null) onSelected(picked);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time, color: Colors.grey.shade500, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    time == null ? 'Select Time' : time.format(context),
                    style: TextStyle(fontSize: 14, color: time == null ? Colors.grey.shade500 : Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static Widget buildDropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required Function(T?) onChanged,
    String? Function(T?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: primaryColor)),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          initialValue: value,
          icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade500),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.grey.shade500, size: 20),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryColor)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red)),
          ),
          items: items,
          onChanged: onChanged,
          validator: validator,
        ),
      ],
    );
  }

  static Widget buildBottomBar({
    required BuildContext context,
    required VoidCallback onCancel,
    required VoidCallback onSave,
    required String saveLabel,
  }) {
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
                onPressed: onCancel,
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryColor,
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
                onPressed: onSave,
                icon: const Icon(Icons.save_outlined, size: 18),
                label: Text(saveLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: primaryColor,
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
