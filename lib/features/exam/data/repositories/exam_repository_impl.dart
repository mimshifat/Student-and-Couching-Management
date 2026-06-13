import 'dart:convert';
import 'package:sqflite/sqflite.dart';
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

  // ---------------------------------------------------------------------------
  // Helper: build a batch snapshot map from the batches table
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>?> _fetchBatchSnapshot(
      DatabaseExecutor db, int batchId) async {
    final rows = await db.query('batches', where: 'id = ?', whereArgs: [batchId]);
    if (rows.isEmpty) return null;
    final b = rows.first;
    return {
      'name': b['name'],
      'schedule_days': b['schedule_days'],
      'time_slot': b['time_slot'],
      'monthly_fee': b['monthly_fee'],
      'description': b['description'],
    };
  }

  @override
  Future<int> insertExam(Exam exam) async {
    final db = await _dbHelper.database;
    final snapshot = await _fetchBatchSnapshot(db, exam.batchId);
    final model = ExamModel.fromEntity(exam.copyWith(batchSnapshot: snapshot));
    return await db.insert(_examTable, model.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<int> updateExam(Exam exam) async {
    final db = await _dbHelper.database;
    // Re-snapshot when batch changes or when snapshot is missing
    final snapshot = await _fetchBatchSnapshot(db, exam.batchId);
    final model = ExamModel.fromEntity(exam.copyWith(batchSnapshot: snapshot));
    return await db.update(
      _examTable,
      model.toMap(),
      where: 'id = ?',
      whereArgs: [model.id],
    );
  }

  @override
  Future<int> deleteExam(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(_examTable, where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------------------
  // Shared SELECT fragment — always bring batch_snapshot + live-joined batch_name
  // as fallback.  The entity's `displayBatchName` getter picks the right one.
  // ---------------------------------------------------------------------------
  static const String _examSelect = '''
    SELECT e.*,
           b.name AS live_batch_name
    FROM exams e
    LEFT JOIN batches b ON e.batch_id = b.id
  ''';

  @override
  Future<List<Exam>> getExamsByBatch(int batchId) async {
    final db = await _dbHelper.database;
    final maps = await db.rawQuery(
        '$_examSelect WHERE e.batch_id = ? ORDER BY e.exam_date DESC', [batchId]);
    return maps.map((m) => ExamModel.fromMap(m)).toList();
  }

  @override
  Future<List<Exam>> getAllExams() async {
    final db = await _dbHelper.database;
    final maps = await db.rawQuery('$_examSelect ORDER BY e.exam_date DESC');
    return maps.map((m) => ExamModel.fromMap(m)).toList();
  }

  @override
  Future<List<Exam>> getFilteredExams(
      {int? year, int? month, int? batchId, String? searchQuery}) async {
    final db = await _dbHelper.database;
    final List<String> conditions = [];
    final List<Object?> args = [];

    if (year != null) {
      conditions.add("strftime('%Y', e.exam_date) = ?");
      args.add(year.toString());
    }
    if (month != null) {
      conditions.add("strftime('%m', e.exam_date) = ?");
      args.add(month.toString().padLeft(2, '0'));
    }
    if (batchId != null) {
      conditions.add('e.batch_id = ?');
      args.add(batchId);
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      conditions.add('LOWER(e.title) LIKE ?');
      args.add('%${searchQuery.toLowerCase()}%');
    }

    final whereClause =
        conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';

    final maps = await db.rawQuery(
        '$_examSelect $whereClause ORDER BY e.exam_date DESC', args);
    return maps.map((m) => ExamModel.fromMap(m)).toList();
  }

  @override
  Future<void> saveResults(int examId, List<ExamResult> results) async {
    final db = await _dbHelper.database;

    // Use an explicit transaction instead of Batch.
    // batch.commit(noResult: true) silently swallows constraint errors;
    // a transaction throws on any failure so callers see real errors.
    await db.transaction((txn) async {
      // 1. Remove all existing rows for this exam.
      await txn.delete(_resultTable, where: 'exam_id = ?', whereArgs: [examId]);

      // 2. Re-insert every result with the latest in-memory values.
      //    'id' is stripped so the DB assigns a fresh ROWID.
      for (final r in results) {
        final map = ResultModel.fromEntity(r).toMap()..remove('id');
        await txn.insert(_resultTable, map);
      }
    });
  }

  @override
  Future<List<ExamResult>> getResultsForExam(int examId) async {
    final db = await _dbHelper.database;
    final maps = await db.rawQuery('''
      SELECT r.*, s.name as student_name
      FROM $_resultTable r
      JOIN students s ON r.student_id = s.id
      WHERE r.exam_id = ?
      ORDER BY s.name ASC
    ''', [examId]);

    return maps.map((m) => ResultModel.fromMap(m)).toList();
  }

  @override
  Future<List<ExamResult>> getResultsForStudent(int studentId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      _resultTable,
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'created_at ASC',
    );

    return maps.map((m) => ResultModel.fromMap(m)).toList();
  }

  @override
  Future<List<ExamResult>> getResultsForStudentAndBatch(
      int studentId, int batchId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      _resultTable,
      where: 'student_id = ? AND batch_id = ?',
      whereArgs: [studentId, batchId],
      orderBy: 'created_at ASC',
    );

    return maps.map((m) => ResultModel.fromMap(m)).toList();
  }

  @override
  Future<List<DetailedResult>> getDetailedResultsForStudent(
      int studentId) async {
    final db = await _dbHelper.database;
    final maps = await db.rawQuery('''
      SELECT r.*,
             e.title as exam_title, e.exam_type, e.exam_date, e.total_marks,
             e.batch_snapshot,
             b.name AS live_batch_name,
             s.name as student_name, s.class_name
      FROM $_resultTable r
      JOIN $_examTable e ON r.exam_id = e.id
      LEFT JOIN batches b ON r.batch_id = b.id
      LEFT JOIN students s ON r.student_id = s.id
      WHERE r.student_id = ?
      ORDER BY e.exam_date DESC
    ''', [studentId]);

    return maps.map((m) => DetailedResultModel.fromMap(m)).toList();
  }

  @override
  Future<List<DetailedResult>> getDetailedResultsByBatch(
      int? batchId) async {
    final db = await _dbHelper.database;
    final whereClause = batchId != null ? 'WHERE r.batch_id = ?' : '';
    final List<Object?> args = batchId != null ? [batchId] : [];

    final maps = await db.rawQuery('''
      SELECT r.*,
             e.title as exam_title, e.exam_type, e.exam_date, e.total_marks,
             e.batch_snapshot,
             b.name AS live_batch_name,
             s.name as student_name, s.class_name
      FROM $_resultTable r
      JOIN $_examTable e ON r.exam_id = e.id
      LEFT JOIN batches b ON r.batch_id = b.id
      LEFT JOIN students s ON r.student_id = s.id
      $whereClause
      ORDER BY b.name ASC, e.exam_date DESC
    ''', args);

    return maps.map((m) => DetailedResultModel.fromMap(m)).toList();
  }

  @override
  Future<List<DetailedResult>> getDetailedResultsForStudentByYear(
      int studentId, int year) async {
    final db = await _dbHelper.database;
    final maps = await db.rawQuery('''
      SELECT r.*,
             e.title as exam_title, e.exam_type, e.exam_date, e.total_marks,
             e.batch_snapshot,
             b.name AS live_batch_name,
             s.name as student_name, s.class_name
      FROM $_resultTable r
      JOIN $_examTable e ON r.exam_id = e.id
      LEFT JOIN batches b ON r.batch_id = b.id
      LEFT JOIN students s ON r.student_id = s.id
      WHERE r.student_id = ? AND strftime('%Y', e.exam_date) = ?
      ORDER BY e.exam_date DESC
    ''', [studentId, year.toString()]);

    return maps.map((m) => DetailedResultModel.fromMap(m)).toList();
  }

  @override
  Future<List<BatchSummary>> getBatchSummaries(int? batchId, int year) async {
    final db = await _dbHelper.database;
    final batchFilter = batchId != null ? 'AND r.batch_id = ?' : '';
    final List<Object?> args = [
      year.toString(),
      ...?(batchId != null ? [batchId] : null),
    ];

    final maps = await db.rawQuery('''
      SELECT
        r.batch_id,
        MAX(b.name) AS live_batch_name,
        (SELECT e2.batch_snapshot FROM $_examTable e2 WHERE e2.id = r.exam_id LIMIT 1) AS batch_snapshot,
        COUNT(r.id)                                           AS total_results,
        SUM(CASE WHEN r.is_absent = 1 OR r.obtained_marks IS NULL
                 THEN 1 ELSE 0 END)                          AS absent_count,
        COALESCE(SUM(CASE WHEN r.is_absent = 0 AND r.obtained_marks IS NOT NULL
                          THEN r.obtained_marks ELSE 0 END), 0) AS total_obtained,
        COALESCE(SUM(CASE WHEN r.is_absent = 0 AND r.obtained_marks IS NOT NULL
                          THEN e.total_marks ELSE 0 END), 0) AS total_available,
        COUNT(DISTINCT r.student_id)                          AS unique_students
      FROM $_resultTable r
      JOIN $_examTable e ON r.exam_id = e.id
      LEFT JOIN batches b ON r.batch_id = b.id
      WHERE strftime('%Y', e.exam_date) = ? $batchFilter
      GROUP BY r.batch_id
    ''', args);

    var summaries = maps.map((m) {
      String finalName = (m['live_batch_name'] as String?) ?? 'Unknown Batch';
      final snapshotJson = m['batch_snapshot'] as String?;
      if (snapshotJson != null && snapshotJson.isNotEmpty) {
         try {
           final map = jsonDecode(snapshotJson);
           if (map['name'] != null) finalName = map['name'];
         } catch (_) {}
      }

      return BatchSummary(
        batchId: m['batch_id'] as int,
        batchName: finalName,
        totalResults: (m['total_results'] as int?) ?? 0,
        absentCount: (m['absent_count'] as int?) ?? 0,
        totalObtained: (m['total_obtained'] as num?)?.toDouble() ?? 0.0,
        totalAvailable: (m['total_available'] as num?)?.toDouble() ?? 0.0,
        uniqueStudents: (m['unique_students'] as int?) ?? 0,
      );
    }).toList();
    
    summaries.sort((a, b) => a.batchName.compareTo(b.batchName));
    return summaries;
  }
}
