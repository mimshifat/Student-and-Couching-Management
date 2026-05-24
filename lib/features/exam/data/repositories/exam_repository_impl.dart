import 'package:sqflite/sqflite.dart' as sqflite;
import '../../domain/entities/exam.dart';
import '../../domain/entities/result.dart';
import '../../domain/repositories/exam_repository.dart';
import '../models/exam_model.dart';
import '../models/result_model.dart';
import '../../../../core/database/database_helper.dart';

class ExamRepositoryImpl implements ExamRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  static const String _examTable = 'exams';
  static const String _resultTable = 'results';

  @override
  Future<int> insertExam(Exam exam) async {
    final db = await _dbHelper.database;
    final model = ExamModel.fromEntity(exam);
    return await db.insert(_examTable, model.toMap(), conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
  }

  @override
  Future<int> deleteExam(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(_examTable, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<Exam>> getExamsByBatch(int batchId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT e.*, b.name as batch_name 
      FROM $_examTable e
      JOIN batches b ON e.batch_id = b.id
      WHERE e.batch_id = ?
      ORDER BY e.exam_date DESC
    ''', [batchId]);

    return List.generate(maps.length, (i) => ExamModel.fromMap(maps[i]));
  }

  @override
  Future<List<Exam>> getAllExams() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT e.*, b.name as batch_name 
      FROM $_examTable e
      JOIN batches b ON e.batch_id = b.id
      ORDER BY e.exam_date DESC
    ''');

    return List.generate(maps.length, (i) => ExamModel.fromMap(maps[i]));
  }

  @override
  Future<void> saveResults(int examId, List<ExamResult> results) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    
    // Delete existing results for this exam to replace them
    batch.delete(_resultTable, where: 'exam_id = ?', whereArgs: [examId]);
    
    for (var r in results) {
      batch.insert(_resultTable, ResultModel.fromEntity(r).toMap());
    }
    
    await batch.commit(noResult: true);
  }

  @override
  Future<List<ExamResult>> getResultsForExam(int examId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT r.*, s.name as student_name
      FROM $_resultTable r
      JOIN students s ON r.student_id = s.id
      WHERE r.exam_id = ?
      ORDER BY s.name ASC
    ''', [examId]);

    return List.generate(maps.length, (i) => ResultModel.fromMap(maps[i]));
  }

  @override
  Future<List<ExamResult>> getResultsForStudent(int studentId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _resultTable,
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'created_at ASC',
    );

    return List.generate(maps.length, (i) => ResultModel.fromMap(maps[i]));
  }

  @override
  Future<List<ExamResult>> getResultsForStudentAndBatch(int studentId, int batchId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _resultTable,
      where: 'student_id = ? AND batch_id = ?',
      whereArgs: [studentId, batchId],
      orderBy: 'created_at ASC',
    );

    return List.generate(maps.length, (i) => ResultModel.fromMap(maps[i]));
  }
}
