import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/note_provider.dart';
import '../../domain/entities/note.dart';

class NoteListScreen extends StatefulWidget {
  const NoteListScreen({super.key});

  @override
  State<NoteListScreen> createState() => _NoteListScreenState();
}

class _NoteListScreenState extends State<NoteListScreen> {
  String _searchQuery = '';
  DateTime? _filterDate;

  void _addOrEditNote(BuildContext context, [Note? note]) {
    final titleCtrl = TextEditingController(text: note?.title);
    final contentCtrl = TextEditingController(text: note?.content);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 16, right: 16, top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(note == null ? 'Add Note' : 'Edit Note', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: contentCtrl,
              decoration: const InputDecoration(labelText: 'Content'),
              maxLines: 5,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (titleCtrl.text.trim().isEmpty || contentCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Title and Content are required')));
                    return;
                  }
                  final newNote = Note(
                    id: note?.id,
                    title: titleCtrl.text.trim(),
                    content: contentCtrl.text.trim(),
                    createdAt: note?.createdAt ?? DateTime.now(),
                    updatedAt: DateTime.now(),
                  );
                  await context.read<NoteProvider>().saveNote(newNote);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _filterDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
        actions: [
          if (_filterDate != null)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Clear Date Filter',
              onPressed: () => setState(() => _filterDate = null),
            ),
          IconButton(
            icon: const Icon(Icons.date_range),
            tooltip: 'Filter by Date',
            onPressed: _pickDate,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SearchBarWidget(
              hintText: 'Search title or content...',
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),
          if (_filterDate != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Text('Filtering by date: ${DateFormat('MMM d, yyyy').format(_filterDate!)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                ],
              ),
            ),
          Expanded(
            child: Consumer<NoteProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.notes.isEmpty) {
                  return const EmptyStateWidget(
                    message: 'No notes created yet.',
                    icon: Icons.notes,
                  );
                }

                final filteredNotes = provider.notes.where((n) {
                  bool matchesSearch = _searchQuery.isEmpty || 
                                       n.title.toLowerCase().contains(_searchQuery) || 
                                       n.content.toLowerCase().contains(_searchQuery);
                  bool matchesDate = _filterDate == null || 
                                     (n.updatedAt.year == _filterDate!.year && 
                                      n.updatedAt.month == _filterDate!.month && 
                                      n.updatedAt.day == _filterDate!.day);
                  return matchesSearch && matchesDate;
                }).toList();

                if (filteredNotes.isEmpty) {
                  return const EmptyStateWidget(
                    message: 'No matching notes found.',
                    icon: Icons.search_off,
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: filteredNotes.length,
                  itemBuilder: (context, index) {
                    final n = filteredNotes[index];
                    return AppCard(
                      onTap: () => _addOrEditNote(context, n),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text(n.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                              IconButton(
                                icon: const Icon(Icons.delete, color: AppTheme.errorColor, size: 20),
                                onPressed: () => provider.deleteNote(n.id!),
                              )
                            ],
                          ),
                          Text(
                            n.content,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 8),
                          Text('Updated: ${DateFormat('dd MMM yyyy, hh:mm a').format(n.updatedAt)}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditNote(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
