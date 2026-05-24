import 'package:sqflite/sqflite.dart' as sqflite;
import '../../domain/entities/student.dart';
import '../../domain/repositories/student_repository.dart';
import '../models/student_model.dart';
import '../../../../core/database/database_helper.dart';

class StudentRepositoryImpl implements StudentRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  static const String _tableName = 'students';

  @override
  Future<int> insertStudent(Student student) async {
    final db = await _dbHelper.database;
    final model = StudentModel.fromEntity(student);
    return await db.insert(_tableName, model.toMap(), conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
  }

  @override
  Future<int> updateStudent(Student student) async {
    final db = await _dbHelper.database;
    final model = StudentModel.fromEntity(student);
    return await db.update(
      _tableName,
      model.toMap(),
      where: 'id = ?',
      whereArgs: [model.id],
    );
  }

  @override
  Future<int> deleteStudent(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<Student?> getStudentById(int id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return StudentModel.fromMap(maps.first);
    }
    return null;
  }

  @override
  Future<List<Student>> getAllStudents() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      orderBy: 'name ASC',
    );

    return List.generate(maps.length, (i) {
      return StudentModel.fromMap(maps[i]);
    });
  }

  @override
  Future<List<Student>> searchStudents(String query) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'name LIKE ? OR phone LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'name ASC',
    );

    return List.generate(maps.length, (i) {
      return StudentModel.fromMap(maps[i]);
    });
  }
}
