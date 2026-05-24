import 'package:flutter/material.dart';
import '../../domain/entities/note.dart';
import '../../domain/repositories/note_repository.dart';

class NoteProvider with ChangeNotifier {
  final NoteRepository _repository;

  List<Note> _notes = [];
  List<Note> get notes => _notes;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  NoteProvider(this._repository) {
    loadNotes();
  }

  Future<void> loadNotes() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _notes = await _repository.getAllNotes();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveNote(Note note) async {
    try {
      if (note.id != null) {
        await _repository.updateNote(note);
      } else {
        await _repository.insertNote(note);
      }
      await loadNotes();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteNote(int id) async {
    try {
      await _repository.deleteNote(id);
      await loadNotes();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
