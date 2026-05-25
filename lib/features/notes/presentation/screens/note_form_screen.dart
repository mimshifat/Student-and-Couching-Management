import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/note.dart';
import '../providers/note_provider.dart';
import '../../../../core/widgets/custom_form_widgets.dart';

class NoteFormScreen extends StatefulWidget {
  final Note? note;

  const NoteFormScreen({super.key, this.note});

  @override
  State<NoteFormScreen> createState() => _NoteFormScreenState();
}

class _NoteFormScreenState extends State<NoteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;
  bool _isPinned = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.note?.title ?? '');
    _contentCtrl = TextEditingController(text: widget.note?.content ?? '');
    _isPinned = widget.note?.isPinned ?? false;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  void _save() async {
    if (_formKey.currentState!.validate()) {
      final newNote = Note(
        id: widget.note?.id,
        title: _titleCtrl.text.trim(),
        content: _contentCtrl.text.trim(),
        isPinned: _isPinned,
        createdAt: widget.note?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await context.read<NoteProvider>().saveNote(newNote);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CustomFormWidgets.backgroundColor,
      appBar: CustomFormWidgets.buildAppBar(
        title: widget.note == null ? 'Add Note' : 'Edit Note',
        subtitle: 'Write down your thoughts',
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
                      CustomFormWidgets.buildSectionHeader('Note Details', Icons.notes_outlined),
                      const SizedBox(height: 20),
                      CustomFormWidgets.buildTextField(
                        label: 'Title *',
                        hint: 'Enter note title',
                        icon: Icons.title,
                        controller: _titleCtrl,
                        validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      CustomFormWidgets.buildTextField(
                        label: 'Content *',
                        hint: 'Enter note content...',
                        icon: Icons.description_outlined,
                        controller: _contentCtrl,
                        maxLines: 6,
                        validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 32),
                      CustomFormWidgets.buildSectionHeader('Settings', Icons.settings_outlined),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SwitchListTile(
                          title: const Text('Pin this note', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: const Text('Pinned notes appear at the top of the list.', style: TextStyle(fontSize: 12)),
                          value: _isPinned,
                          activeThumbColor: CustomFormWidgets.primaryColor,
                          onChanged: (val) {
                            setState(() => _isPinned = val);
                          },
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
              onSave: _save,
              saveLabel: widget.note == null ? 'Save Note' : 'Update Note',
            ),
          ],
        ),
      ),
    );
  }
}
