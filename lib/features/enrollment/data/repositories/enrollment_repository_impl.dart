import 'package:sqflite/sqflite.dart' as sqflite;
import '../../domain/entities/enrollment.dart';
import '../../domain/repositories/enrollment_repository.dart';
import '../models/enrollment_model.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/utils/date_utils.dart';

class EnrollmentRepositoryImpl implements EnrollmentRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  static const String _tableName = 'enrollments';

  @override
  Future<int> enrollStudent(Enrollment enrollment) async {
    final db = await _dbHelper.database;
    
    // Fetch student's current class to snapshot it
    final studentMap = await db.query('students', where: 'id = ?', whereArgs: [enrollment.studentId]);
    final studentClass = studentMap.isNotEmpty ? studentMap.first['class_name'] as String? : null;

    // Fetch batch details to snapshot them
    final batchMap = await db.query('batches', where: 'id = ?', whereArgs: [enrollment.batchId]);
    String? batchName;
    String? batchScheduleDays;
    String? batchTimeSlot;
    if (batchMap.isNotEmpty) {
      batchName = batchMap.first['name'] as String?;
      batchScheduleDays = batchMap.first['schedule_days'] as String?;
      batchTimeSlot = batchMap.first['time_slot'] as String?;
    }

    final enrollmentWithSnapshots = enrollment.copyWith(
      studentClass: studentClass,
      batchNameSnapshot: batchName,
      batchScheduleDaysSnapshot: batchScheduleDays,
      batchTimeSlotSnapshot: batchTimeSlot,
    );
    final model = EnrollmentModel.fromEntity(enrollmentWithSnapshots);
    return await db.insert(_tableName, model.toMap(), conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
  }

  @override
  Future<int> deactivateEnrollment(int id, DateTime leaveDate) async {
    final db = await _dbHelper.database;
    return await db.update(
      _tableName,
      {'leave_date': DateUtilsHelper.formatForDb(leaveDate)},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<int> updateFeeOverride(int id, double? feeOverride) async {
    final db = await _dbHelper.database;
    return await db.update(
      _tableName,
      {'fee_override': feeOverride},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<List<Enrollment>> getActiveEnrollments(int studentId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT e.*, COALESCE(e.batch_name, b.name) as batch_name 
      FROM $_tableName e 
      JOIN batches b ON e.batch_id = b.id 
      WHERE e.student_id = ? AND e.leave_date IS NULL
      ORDER BY e.join_date DESC
    ''', [studentId]);

    return List.generate(maps.length, (i) => EnrollmentModel.fromMap(maps[i]));
  }

  @override
  Future<List<Enrollment>> getEnrollmentHistory(int studentId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT e.*, COALESCE(e.batch_name, b.name) as batch_name 
      FROM $_tableName e 
      JOIN batches b ON e.batch_id = b.id 
      WHERE e.student_id = ?
      ORDER BY e.join_date DESC
    ''', [studentId]);

    return List.generate(maps.length, (i) => EnrollmentModel.fromMap(maps[i]));
  }

  @override
  Future<List<Enrollment>> getAllEnrollments() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(_tableName);
    return List.generate(maps.length, (i) => EnrollmentModel.fromMap(maps[i]));
  }

  @override
  Future<List<Enrollment>> getStudentsByBatch(int batchId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT e.*, s.name as student_name 
      FROM $_tableName e 
      JOIN students s ON e.student_id = s.id 
      WHERE e.batch_id = ? AND e.leave_date IS NULL
      ORDER BY s.name ASC
    ''', [batchId]);

    return List.generate(maps.length, (i) => EnrollmentModel.fromMap(maps[i]));
  }

  @override
  Future<bool> isStudentActive(int studentId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM $_tableName 
      WHERE student_id = ? AND leave_date IS NULL
    ''', [studentId]);

    int count = sqflite.Sqflite.firstIntValue(result) ?? 0;
    return count > 0;
  }
}
