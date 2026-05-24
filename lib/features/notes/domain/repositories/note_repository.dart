import '../entities/note.dart';

abstract class NoteRepository {
  Future<int> insertNote(Note note);
  Future<int> updateNote(Note note);
  Future<int> deleteNote(int id);
  Future<List<Note>> getAllNotes();
}
