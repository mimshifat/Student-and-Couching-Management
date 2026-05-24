import 'package:sqflite/sqflite.dart' as sqflite;
import '../../domain/entities/fee_record.dart';
import '../../domain/repositories/fee_repository.dart';
import '../models/fee_record_model.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/utils/date_utils.dart';

class FeeRepositoryImpl implements FeeRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  static const String _feeTable = 'fee_records';

  @override
  Future<List<FeeRecord>> getFeeRecordsForStudent(int studentId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT f.*, s.name as student_name
      FROM $_feeTable f
      JOIN students s ON f.student_id = s.id
      WHERE f.student_id = ?
      ORDER BY f.year DESC, f.month DESC
    ''', [studentId]);

    return List.generate(maps.length, (i) => FeeRecordModel.fromMap(maps[i]));
  }

  @override
  Future<List<FeeRecord>> getPendingFeeRecords() async {
    final db = await _dbHelper.database;
    // We fetch all records for the overview instead of just pending ones
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT f.*, s.name as student_name
      FROM $_feeTable f
      JOIN students s ON f.student_id = s.id
      ORDER BY s.name ASC, f.year DESC, f.month DESC
    ''');

    return List.generate(maps.length, (i) => FeeRecordModel.fromMap(maps[i]));
  }

  @override
  Future<void> generateFeeRecords(int studentId, DateTime studentCreatedAt) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();

    // Fetch all enrollments for this student
    final enrollmentsMap = await db.query('enrollments', where: 'student_id = ?', whereArgs: [studentId]);
    final batchesMap = await db.query('batches');
    
    // Create a lookup for batches
    Map<int, double> batchFees = {};
    Map<int, bool> batchActive = {};
    for (var b in batchesMap) {
      batchFees[b['id'] as int] = (b['monthly_fee'] as num?)?.toDouble() ?? 0.0;
      batchActive[b['id'] as int] = (b['is_active'] == null || b['is_active'] == 1);
    }

    // Determine the start date (earliest of student creation date or earliest join date)
    DateTime startDate = studentCreatedAt;
    for (var e in enrollmentsMap) {
      final joinDate = DateUtilsHelper.parseFromDb(e['join_date'] as String);
      if (joinDate.isBefore(startDate)) startDate = joinDate;
    }

    // Iterate through calendar months up to current month
    DateTime currentIterator = DateTime(startDate.year, startDate.month, 1);
    final endIterator = DateTime(now.year, now.month, 1);

    while (!currentIterator.isAfter(endIterator)) {
      final int year = currentIterator.year;
      final int month = currentIterator.month;

      // Check if fee record already exists for this month and year
      final existingRecord = await db.query(
        _feeTable,
        where: 'student_id = ? AND month = ? AND year = ?',
        whereArgs: [studentId, month, year],
      );

      if (existingRecord.isEmpty) {
        // Calculate fee for this month
        double totalMonthlyFee = 0.0;
        int daysInMonth = DateTime(year, month + 1, 0).day;
        DateTime firstDayOfMonth = DateTime(year, month, 1);
        DateTime lastDayOfMonth = DateTime(year, month, daysInMonth);

        // Find active enrollments for this month
        List<Map<String, dynamic>> activeEnrollments = [];
        for (var e in enrollmentsMap) {
          final joinDate = DateUtilsHelper.parseFromDb(e['join_date'] as String);
          final leaveDateStr = e['leave_date'] as String?;
          final leaveDate = leaveDateStr != null ? DateUtilsHelper.parseFromDb(leaveDateStr) : null;

          if (joinDate.isBefore(lastDayOfMonth.add(const Duration(days: 1))) &&
              (leaveDate == null || leaveDate.isAfter(firstDayOfMonth.subtract(const Duration(days: 1))))) {
            activeEnrollments.add(e);
          }
        }

        if (activeEnrollments.isNotEmpty) {
          // Batch Student logic
          for (var e in activeEnrollments) {
            final batchId = e['batch_id'] as int;
            if (batchActive[batchId] == false) continue; // Skip inactive batches

            final joinDate = DateUtilsHelper.parseFromDb(e['join_date'] as String);
            final leaveDateStr = e['leave_date'] as String?;
            final leaveDate = leaveDateStr != null ? DateUtilsHelper.parseFromDb(leaveDateStr) : null;
            
            double batchFee = batchFees[batchId] ?? 0.0;
            double finalBatchFee = batchFee;
            if (finalBatchFee < 0) finalBatchFee = 0;

            DateTime effectiveStart = joinDate.isAfter(firstDayOfMonth) ? joinDate : firstDayOfMonth;
            DateTime effectiveEnd = (leaveDate != null && leaveDate.isBefore(lastDayOfMonth)) ? leaveDate : lastDayOfMonth;
            
            int activeDays = effectiveEnd.difference(effectiveStart).inDays + 1;
            if (activeDays > daysInMonth) activeDays = daysInMonth;
            if (activeDays > 0) {
              totalMonthlyFee += (finalBatchFee / daysInMonth) * activeDays;
            }
          }
        }

        // Insert Fee Record if amount > 0
        if (totalMonthlyFee > 0) {
          final feeRecord = FeeRecordModel(
            studentId: studentId,
            month: month,
            year: year,
            totalAmount: totalMonthlyFee,
            paidAmount: 0.0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          await db.insert(_feeTable, feeRecord.toMap(), conflictAlgorithm: sqflite.ConflictAlgorithm.ignore);
        }
      }

      // Move to next month
      currentIterator = DateTime(year, month + 1, 1);
    }
  }

  @override
  Future<void> updatePaidAmount(int feeRecordId, double paidAmount) async {
    final db = await _dbHelper.database;
    final nowStr = DateUtilsHelper.formatForDb(DateTime.now());

    await db.update(
      _feeTable,
      {
        'paid_amount': paidAmount,
        'updated_at': nowStr,
      },
      where: 'id = ?',
      whereArgs: [feeRecordId],
    );
  }
}
