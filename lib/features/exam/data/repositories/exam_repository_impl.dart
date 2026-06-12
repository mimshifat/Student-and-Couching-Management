import 'package:sqflite/sqflite.dart' as sqflite;
import '../../domain/entities/exam.dart';
import '../../domain/entities/result.dart';
import '../../domain/entities/detailed_result.dart';
import '../../domain/entities/batch_summary.dart';
import '../../domain/repositories/exam_repository.dart';
import '../models/exam_model.dart';
import '../models/result_model.dart';
import '../models/detailed_result_model.dart';
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
  Future<int> updateExam(Exam exam) async {
    final db = await _dbHelper.database;
    final model = ExamModel.fromEntity(exam);
    return await db.update(
      _examTable, 
      model.toMap(), 
      where: 'id = ?', 
      whereArgs: [model.id]
    );
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
  Future<List<Exam>> getFilteredExams({int? year, int? month, int? batchId, String? searchQuery}) async {
    final db = await _dbHelper.database;
    final List<String> conditions = [];
    final List<Object?> args = [];

    if (year != null) {
      conditions.add("strftime('%Y', e.exam_date) = ?");
      args.add(year.toString());
    }
    if (month != null) {
      // month format in SQLite is '01' through '12'
      conditions.add("strftime('%m', e.exam_date) = ?");
      args.add(month.toString().padLeft(2, '0'));
    }
    if (batchId != null) {
      conditions.add("e.batch_id = ?");
      args.add(batchId);
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      conditions.add("LOWER(e.title) LIKE ?");
      args.add('%${searchQuery.toLowerCase()}%');
    }

    final String whereClause = conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT e.*, b.name as batch_name 
      FROM $_examTable e
      JOIN batches b ON e.batch_id = b.id
      $whereClause
      ORDER BY e.exam_date DESC
    ''', args);

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

  @override
  Future<List<DetailedResult>> getDetailedResultsForStudent(int studentId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT r.*, 
             e.title as exam_title, e.exam_type, e.exam_date, e.total_marks,
             b.name as batch_name, 
             s.name as student_name, s.class_name
      FROM $_resultTable r
      JOIN $_examTable e ON r.exam_id = e.id
      LEFT JOIN batches b ON r.batch_id = b.id
      LEFT JOIN students s ON r.student_id = s.id
      WHERE r.student_id = ?
      ORDER BY e.exam_date DESC
    ''', [studentId]);

    return List.generate(maps.length, (i) => DetailedResultModel.fromMap(maps[i]));
  }

  @override
  Future<List<DetailedResult>> getDetailedResultsByBatch(int? batchId) async {
    final db = await _dbHelper.database;
    final String whereClause = batchId != null ? 'WHERE r.batch_id = ?' : '';
    final List<Object?> args = batchId != null ? [batchId] : [];

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT r.*, 
             e.title as exam_title, e.exam_type, e.exam_date, e.total_marks,
             b.name as batch_name,
             s.name as student_name, s.class_name
      FROM $_resultTable r
      JOIN $_examTable e ON r.exam_id = e.id
      LEFT JOIN batches b ON r.batch_id = b.id
      LEFT JOIN students s ON r.student_id = s.id
      $whereClause
      ORDER BY b.name ASC, e.exam_date DESC
    ''', args);

    return List.generate(maps.length, (i) => DetailedResultModel.fromMap(maps[i]));
  }

  @override
  Future<List<DetailedResult>> getDetailedResultsForStudentByYear(
      int studentId, int year) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT r.*,
             e.title as exam_title, e.exam_type, e.exam_date, e.total_marks,
             b.name as batch_name,
             s.name as student_name, s.class_name
      FROM $_resultTable r
      JOIN $_examTable e ON r.exam_id = e.id
      LEFT JOIN batches b ON r.batch_id = b.id
      LEFT JOIN students s ON r.student_id = s.id
      WHERE r.student_id = ? AND strftime('%Y', e.exam_date) = ?
      ORDER BY e.exam_date DESC
    ''', [studentId, year.toString()]);
    return List.generate(maps.length, (i) => DetailedResultModel.fromMap(maps[i]));
  }

  @override
  Future<List<BatchSummary>> getBatchSummaries(int? batchId, int year) async {
    final db = await _dbHelper.database;
    final String batchFilter = batchId != null ? 'AND r.batch_id = ?' : '';
    final List<Object?> args = [
      year.toString(),
      ...?( batchId != null ? [batchId] : null),
    ];

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT
        r.batch_id,
        b.name                                          AS batch_name,
        COUNT(r.id)                                     AS total_results,
        SUM(CASE WHEN r.is_absent = 1 OR r.obtained_marks IS NULL
                 THEN 1 ELSE 0 END)                     AS absent_count,
        COALESCE(SUM(CASE WHEN r.is_absent = 0 AND r.obtained_marks IS NOT NULL
                          THEN r.obtained_marks ELSE 0 END), 0) AS total_obtained,
        COALESCE(SUM(CASE WHEN r.is_absent = 0 AND r.obtained_marks IS NOT NULL
                          THEN e.total_marks ELSE 0 END), 0) AS total_available,
        COUNT(DISTINCT r.student_id)                    AS unique_students
      FROM $_resultTable r
      JOIN $_examTable e ON r.exam_id = e.id
      LEFT JOIN batches b ON r.batch_id = b.id
      WHERE strftime('%Y', e.exam_date) = ? $batchFilter
      GROUP BY r.batch_id, b.name
      ORDER BY b.name ASC
    ''', args);

    return maps.map((m) => BatchSummary(
      batchId: m['batch_id'] as int,
      batchName: (m['batch_name'] as String?) ?? 'Unknown Batch',
      totalResults: (m['total_results'] as int?) ?? 0,
      absentCount: (m['absent_count'] as int?) ?? 0,
      totalObtained: (m['total_obtained'] as num?)?.toDouble() ?? 0.0,
      totalAvailable: (m['total_available'] as num?)?.toDouble() ?? 0.0,
      uniqueStudents: (m['unique_students'] as int?) ?? 0,
    )).toList();
  }
}
