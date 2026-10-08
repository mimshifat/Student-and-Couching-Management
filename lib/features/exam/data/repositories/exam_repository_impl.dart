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
    final result = await db.update(
      _examTable,
      model.toMap(),
      where: 'id = ?',
      whereArgs: [model.id],
    );

    // (Removed automatic score capping to prevent silent data loss)

    return result;
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
      {int? year, int? startMonth, int? endMonth, int? batchId, String? searchQuery}) async {
    final db = await _dbHelper.database;
    final List<String> conditions = [];
    final List<Object?> args = [];

    if (year != null) {
      conditions.add("strftime('%Y', e.exam_date) = ?");
      args.add(year.toString());
    }
    if (startMonth != null && endMonth != null) {
      // Month range filter
      conditions.add("CAST(strftime('%m', e.exam_date) AS INTEGER) >= ?");
      args.add(startMonth);
      conditions.add("CAST(strftime('%m', e.exam_date) AS INTEGER) <= ?");
      args.add(endMonth);
    } else if (startMonth != null) {
      // Single month filter
      conditions.add("strftime('%m', e.exam_date) = ?");
      args.add(startMonth.toString().padLeft(2, '0'));
    } else if (endMonth != null) {
      conditions.add("strftime('%m', e.exam_date) = ?");
      args.add(endMonth.toString().padLeft(2, '0'));
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
      final existingDbResults = await txn.query(_resultTable, columns: ['id'], where: 'exam_id = ?', whereArgs: [examId]);
      final existingIds = existingDbResults.map((m) => m['id'] as int).toSet();
      
      final newIds = results.map((r) => r.id).where((id) => id != null).cast<int>().toSet();
      
      final idsToDelete = existingIds.difference(newIds);
      if (idsToDelete.isNotEmpty) {
        await txn.delete(_resultTable, where: 'id IN (${idsToDelete.join(',')})');
      }
      
      for (final r in results) {
        final map = ResultModel.fromEntity(r).toMap();
        if (r.id == null) {
          map.remove('id');
          await txn.insert(_resultTable, map);
        } else {
          await txn.update(_resultTable, map, where: 'id = ?', whereArgs: [r.id]);
        }
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
             e.exam_fee, e.batch_snapshot,
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
      int? batchId, {int? year, int? startMonth, int? endMonth}) async {
    final db = await _dbHelper.database;
    final List<String> conditions = [];
    final List<Object?> args = [];

    if (batchId != null) {
      conditions.add('r.batch_id = ?');
      args.add(batchId);
    }
    if (year != null) {
      conditions.add("strftime('%Y', e.exam_date) = ?");
      args.add(year.toString());
    }
    if (startMonth != null && endMonth != null) {
      conditions.add("CAST(strftime('%m', e.exam_date) AS INTEGER) >= ?");
      args.add(startMonth);
      conditions.add("CAST(strftime('%m', e.exam_date) AS INTEGER) <= ?");
      args.add(endMonth);
    } else if (startMonth != null) {
      conditions.add("strftime('%m', e.exam_date) = ?");
      args.add(startMonth.toString().padLeft(2, '0'));
    } else if (endMonth != null) {
      conditions.add("strftime('%m', e.exam_date) = ?");
      args.add(endMonth.toString().padLeft(2, '0'));
    }

    final whereClause = conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';

    final maps = await db.rawQuery('''
      SELECT r.*,
             e.title as exam_title, e.exam_type, e.exam_date, e.total_marks,
             e.exam_fee, e.batch_snapshot,
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
  Future<List<DetailedResult>> getDetailedResultsForStudentFiltered(
      int studentId, {int? year, int? startMonth, int? endMonth}) async {
    final db = await _dbHelper.database;
    final List<String> conditions = ['r.student_id = ?'];
    final List<Object?> args = [studentId];

    if (year != null) {
      conditions.add("strftime('%Y', e.exam_date) = ?");
      args.add(year.toString());
    }
    if (startMonth != null && endMonth != null) {
      conditions.add("CAST(strftime('%m', e.exam_date) AS INTEGER) >= ?");
      args.add(startMonth);
      conditions.add("CAST(strftime('%m', e.exam_date) AS INTEGER) <= ?");
      args.add(endMonth);
    } else if (startMonth != null) {
      conditions.add("strftime('%m', e.exam_date) = ?");
      args.add(startMonth.toString().padLeft(2, '0'));
    } else if (endMonth != null) {
      conditions.add("strftime('%m', e.exam_date) = ?");
      args.add(endMonth.toString().padLeft(2, '0'));
    }

    final whereClause = conditions.join(' AND ');

    final maps = await db.rawQuery('''
      SELECT r.*,
             e.title as exam_title, e.exam_type, e.exam_date, e.total_marks,
             e.exam_fee, e.batch_snapshot,
             b.name AS live_batch_name,
             s.name as student_name, s.class_name
      FROM $_resultTable r
      JOIN $_examTable e ON r.exam_id = e.id
      LEFT JOIN batches b ON r.batch_id = b.id
      LEFT JOIN students s ON r.student_id = s.id
      WHERE $whereClause
      ORDER BY e.exam_date DESC
    ''', args);

    return maps.map((m) => DetailedResultModel.fromMap(m)).toList();
  }

  @override
  Future<List<BatchSummary>> getBatchSummaries(int? batchId, {int? year, int? startMonth, int? endMonth}) async {
    final db = await _dbHelper.database;
    final List<String> conditions = [];
    final List<Object?> args = [];

    if (year != null) {
      conditions.add("strftime('%Y', e.exam_date) = ?");
      args.add(year.toString());
    }
    if (startMonth != null && endMonth != null) {
      conditions.add("CAST(strftime('%m', e.exam_date) AS INTEGER) >= ?");
      args.add(startMonth);
      conditions.add("CAST(strftime('%m', e.exam_date) AS INTEGER) <= ?");
      args.add(endMonth);
    } else if (startMonth != null) {
      conditions.add("strftime('%m', e.exam_date) = ?");
      args.add(startMonth.toString().padLeft(2, '0'));
    } else if (endMonth != null) {
      conditions.add("strftime('%m', e.exam_date) = ?");
      args.add(endMonth.toString().padLeft(2, '0'));
    }
    
    if (batchId != null) {
      conditions.add('r.batch_id = ?');
      args.add(batchId);
    }
    
    final whereClause = conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';

    final maps = await db.rawQuery('''
      SELECT
        r.batch_id,
        MAX(b.name) AS live_batch_name,
        (SELECT e2.batch_snapshot FROM $_examTable e2 WHERE e2.id = r.exam_id LIMIT 1) AS batch_snapshot,
        COUNT(DISTINCT r.exam_id)                             AS total_exams,
        COUNT(r.id)                                           AS total_results,
        SUM(CASE WHEN r.is_absent = 1 THEN 1 ELSE 0 END) AS absent_count,
        COALESCE(SUM(CASE WHEN r.is_absent = 0 AND r.obtained_marks IS NOT NULL
                          THEN r.obtained_marks ELSE 0 END), 0) AS total_obtained,
        COALESCE(SUM(CASE WHEN r.is_absent = 0 AND r.obtained_marks IS NOT NULL
                          THEN e.total_marks ELSE 0 END), 0) AS total_available,
        COUNT(DISTINCT r.student_id)                          AS total_students,
        COUNT(DISTINCT CASE WHEN r.is_absent = 0 THEN r.student_id END) AS present_students
      FROM $_resultTable r
      JOIN $_examTable e ON r.exam_id = e.id
      LEFT JOIN batches b ON r.batch_id = b.id
      $whereClause
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
        totalExams: (m['total_exams'] as int?) ?? 0,
        absentCount: (m['absent_count'] as int?) ?? 0,
        totalObtained: (m['total_obtained'] as num?)?.toDouble() ?? 0.0,
        totalAvailable: (m['total_available'] as num?)?.toDouble() ?? 0.0,
        totalStudents: (m['total_students'] as int?) ?? 0,
        presentStudents: (m['present_students'] as int?) ?? 0,
      );
    }).toList();
    
    summaries.sort((a, b) => a.batchName.compareTo(b.batchName));
    return summaries;
  }
}
