import 'package:sqflite/sqflite.dart' as sqflite;
import '../../domain/entities/note.dart';
import '../../domain/repositories/note_repository.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/utils/date_utils.dart';

class NoteModel extends Note {
  NoteModel({
    super.id,
    required super.title,
    required super.content,
    required super.isPinned,
    required super.createdAt,
    required super.updatedAt,
  });

  factory NoteModel.fromEntity(Note entity) {
    return NoteModel(
      id: entity.id,
      title: entity.title,
      content: entity.content,
      isPinned: entity.isPinned,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  factory NoteModel.fromMap(Map<String, dynamic> map) {
    return NoteModel(
      id: map['id'],
      title: map['title'],
      content: map['content'],
      isPinned: map['is_pinned'] == 1,
      createdAt: DateUtilsHelper.parseFromDb(map['created_at']),
      updatedAt: DateUtilsHelper.parseFromDb(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'is_pinned': isPinned ? 1 : 0,
      'created_at': DateUtilsHelper.formatForDb(createdAt),
      'updated_at': DateUtilsHelper.formatForDb(updatedAt),
    };
  }
}

class NoteRepositoryImpl implements NoteRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  static const String _table = 'notes';

  @override
  Future<int> insertNote(Note note) async {
    final db = await _dbHelper.database;
    final model = NoteModel.fromEntity(note);
    return await db.insert(_table, model.toMap(), conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
  }

  @override
  Future<int> updateNote(Note note) async {
    final db = await _dbHelper.database;
    final model = NoteModel.fromEntity(note);
    return await db.update(_table, model.toMap(), where: 'id = ?', whereArgs: [note.id]);
  }

  @override
  Future<int> deleteNote(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<Note>> getAllNotes() async {
    final db = await _dbHelper.database;
    final maps = await db.query(_table, orderBy: 'is_pinned DESC, updated_at DESC');
    return List.generate(maps.length, (i) => NoteModel.fromMap(maps[i]));
  }
}
