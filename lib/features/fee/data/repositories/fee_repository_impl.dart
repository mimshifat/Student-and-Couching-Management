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
    final studentMap = await db.query('students', where: 'id = ?', whereArgs: [studentId]);
    final studentClass = studentMap.isNotEmpty ? studentMap.first['class_name'] as String? : null;

    final batchesMap = await db.query('batches');
    
    // Create a lookup for batches
    Map<int, double> batchFees = {};
    Map<int, bool> batchActive = {};
    Map<int, Map<String, dynamic>> batchLookup = {};
    for (var b in batchesMap) {
      batchFees[b['id'] as int] = (b['monthly_fee'] as num?)?.toDouble() ?? 0.0;
      batchActive[b['id'] as int] = (b['is_active'] == null || b['is_active'] == 1);
      batchLookup[b['id'] as int] = b;
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

      // Check if an old legacy aggregated record exists for this month.
      // If it exists, we skip generating new batch-specific records for this month
      // to avoid double charging students for months already processed before this update.
      final oldAggregatedRecord = await db.query(
        _feeTable,
        where: 'student_id = ? AND month = ? AND year = ? AND batch_id IS NULL',
        whereArgs: [studentId, month, year],
      );

      if (oldAggregatedRecord.isNotEmpty) {
        // Move to next month
        currentIterator = DateTime(year, month + 1, 1);
        continue;
      }

      int daysInMonth = DateTime(year, month + 1, 0).day;
      DateTime firstDayOfMonth = DateTime(year, month, 1);
      DateTime lastDayOfMonth = DateTime(year, month, daysInMonth);

      // Get all existing batch-specific fee records for this month
      final existingRecords = await db.query(
        _feeTable,
        where: 'student_id = ? AND month = ? AND year = ? AND batch_id IS NOT NULL',
        whereArgs: [studentId, month, year],
      );
      
      Map<int, Map<String, dynamic>> existingRecordsByBatch = {};
      for (var r in existingRecords) {
        existingRecordsByBatch[r['batch_id'] as int] = r;
      }

      for (var e in enrollmentsMap) {
        final batchId = e['batch_id'] as int;
        
        final joinDate = DateUtilsHelper.parseFromDb(e['join_date'] as String);
        final leaveDateStr = e['leave_date'] as String?;
        final leaveDate = leaveDateStr != null ? DateUtilsHelper.parseFromDb(leaveDateStr) : null;

        double batchMonthlyFee = 0.0;
        String snapshotText = 'Unknown';
        bool isPartialMonth = false;
        
        bool isActiveThisMonth = joinDate.isBefore(lastDayOfMonth.add(const Duration(days: 1))) &&
            (leaveDate == null || leaveDate.isAfter(firstDayOfMonth.subtract(const Duration(days: 1))));

        if (isActiveThisMonth && batchActive[batchId] != false) {
          final batch = batchLookup[batchId];
          if (batch != null) {
            String bName = (e['batch_name'] as String?) ?? (batch['name'] as String?) ?? 'Unknown';
            String bDays = (e['batch_schedule_days'] as String?) ?? (batch['schedule_days'] as String?) ?? '';
            String bTime = (e['batch_time_slot'] as String?) ?? (batch['time_slot'] as String?) ?? '';
            snapshotText = bName;
            if (bDays.isNotEmpty && bTime.isNotEmpty) {
               snapshotText += ' ($bDays | $bTime)';
            }
          }
          
          final feeOverrideObj = e['fee_override'];
          double? feeOverride = feeOverrideObj != null ? (feeOverrideObj as num).toDouble() : null;

          double batchFee = batchFees[batchId] ?? 0.0;
          double finalBatchFee = feeOverride ?? batchFee;
          if (finalBatchFee < 0) finalBatchFee = 0;

          DateTime effectiveStart = joinDate.isAfter(firstDayOfMonth) ? joinDate : firstDayOfMonth;
          DateTime effectiveEnd = (leaveDate != null && leaveDate.isBefore(lastDayOfMonth)) ? leaveDate : lastDayOfMonth;
          
          int activeDays = effectiveEnd.difference(effectiveStart).inDays + 1;
          if (activeDays > daysInMonth) activeDays = daysInMonth;
          if (activeDays < daysInMonth) isPartialMonth = true;
          if (activeDays > 0) {
            batchMonthlyFee = (finalBatchFee / daysInMonth) * activeDays;
          }
        }

        final existingRecord = existingRecordsByBatch[batchId];

        if (existingRecord == null) {
          if (batchMonthlyFee > 0) {
            final feeRecord = FeeRecordModel(
              studentId: studentId,
              month: month,
              year: year,
              totalAmount: batchMonthlyFee,
              paidAmount: 0.0,
              studentClass: studentClass,
              batchId: batchId,
              batchDetailsSnapshot: snapshotText,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            await db.insert(_feeTable, feeRecord.toMap(), conflictAlgorithm: sqflite.ConflictAlgorithm.ignore);
          }
        } else {
          final id = existingRecord['id'] as int;
          final paidAmount = (existingRecord['paid_amount'] as num).toDouble();
          final currentTotalAmount = (existingRecord['total_amount'] as num).toDouble();

          if (batchMonthlyFee == 0) {
            if (paidAmount == 0) {
              await db.delete(_feeTable, where: 'id = ?', whereArgs: [id]);
            } else if (currentTotalAmount != 0) {
              await db.update(
                _feeTable,
                {
                  'total_amount': 0.0,
                  'updated_at': DateUtilsHelper.formatForDb(DateTime.now()),
                },
                where: 'id = ?',
                whereArgs: [id],
              );
            }
          } else if (batchMonthlyFee != currentTotalAmount) {
            bool isPastMonth = year < now.year || (year == now.year && month < now.month);
            
            if (!isPastMonth || isPartialMonth) {
              await db.update(
                _feeTable,
                {
                  'total_amount': batchMonthlyFee,
                  'updated_at': DateUtilsHelper.formatForDb(DateTime.now()),
                },
                where: 'id = ?',
                whereArgs: [id],
              );
            }
          }
          
          existingRecordsByBatch.remove(batchId);
        }
      }

      for (var entry in existingRecordsByBatch.entries) {
        final id = entry.value['id'] as int;
        final paidAmount = (entry.value['paid_amount'] as num).toDouble();
        if (paidAmount == 0) {
          await db.delete(_feeTable, where: 'id = ?', whereArgs: [id]);
        } else {
          await db.update(
            _feeTable,
            {
              'total_amount': 0.0,
              'updated_at': DateUtilsHelper.formatForDb(DateTime.now()),
            },
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      }

      // Move to next month
      currentIterator = DateTime(year, month + 1, 1);
    }
  }

  @override
  Future<void> updatePaidAmount(int feeRecordId, double paidAmount, {bool isSettled = false, String? note}) async {
    final db = await _dbHelper.database;
    final nowStr = DateUtilsHelper.formatForDb(DateTime.now());

    final Map<String, dynamic> updateData = {
      'paid_amount': paidAmount,
      'is_settled': isSettled ? 1 : 0,
      'updated_at': nowStr,
    };
    if (paidAmount > 0 || isSettled) {
      updateData['payment_date'] = nowStr;
    }
    if (note != null) {
      updateData['note'] = note;
    }

    await db.update(
      _feeTable,
      updateData,
      where: 'id = ?',
      whereArgs: [feeRecordId],
    );
  }
}
