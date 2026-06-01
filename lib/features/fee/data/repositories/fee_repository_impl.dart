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
      WHERE s.deleted_at IS NULL
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

    final inactivePeriodsMap = await db.query('batch_inactive_periods');
    Map<int, List<Map<String, dynamic>>> inactivePeriodsByBatch = {};
    for (var p in inactivePeriodsMap) {
      final batchId = p['batch_id'] as int;
      inactivePeriodsByBatch.putIfAbsent(batchId, () => []).add(p);
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
      Map<int, List<Map<String, dynamic>>> allExistingRecordsByBatch = {};
      for (var r in existingRecords) {
        final batchId = r['batch_id'] as int;
        allExistingRecordsByBatch.putIfAbsent(batchId, () => []).add(r);
      }

      // Consolidate duplicates if any
      for (var batchId in allExistingRecordsByBatch.keys) {
        final records = allExistingRecordsByBatch[batchId]!;
        if (records.length > 1) {
          double totalPaid = 0.0;
          double maxTotalAmount = 0.0;
          String? paymentDate;
          String? note;
          int isSettled = 0;
          
          Map<String, dynamic> mainRecord = Map.from(records.first);
          
          for (var r in records) {
             totalPaid += (r['paid_amount'] as num).toDouble();
             double rTotal = (r['total_amount'] as num).toDouble();
             if (rTotal > maxTotalAmount) maxTotalAmount = rTotal;
             if (r['is_settled'] == 1) isSettled = 1;
             if (r['payment_date'] != null) paymentDate = r['payment_date'] as String;
             if (r['note'] != null) {
                note = note == null ? r['note'] : '$note\n${r['note']}';
             }
          }
          
          await db.update(_feeTable, {
            'paid_amount': totalPaid,
            'total_amount': maxTotalAmount,
            'is_settled': isSettled,
            'payment_date': paymentDate,
            'note': note,
          }, where: 'id = ?', whereArgs: [mainRecord['id']]);
          
          for (int i = 1; i < records.length; i++) {
             await db.delete(_feeTable, where: 'id = ?', whereArgs: [records[i]['id']]);
          }
          
          mainRecord['paid_amount'] = totalPaid;
          mainRecord['total_amount'] = maxTotalAmount;
          mainRecord['is_settled'] = isSettled;
          existingRecordsByBatch[batchId] = mainRecord;
        } else {
          existingRecordsByBatch[batchId] = records.first;
        }
      }

      // Group enrollments by batch
      Map<int, List<Map<String, dynamic>>> enrollmentsByBatch = {};
      for (var e in enrollmentsMap) {
        final batchId = e['batch_id'] as int;
        enrollmentsByBatch.putIfAbsent(batchId, () => []).add(e);
      }

      for (var batchEntry in enrollmentsByBatch.entries) {
        final batchId = batchEntry.key;
        final enrollments = batchEntry.value;
        
        double totalBatchMonthlyFee = 0.0;
        String snapshotText = 'Unknown';
        bool isPartialMonth = false;
        
        for (var e in enrollments) {
          final joinDate = DateUtilsHelper.parseFromDb(e['join_date'] as String);
          final leaveDateStr = e['leave_date'] as String?;
          final leaveDate = leaveDateStr != null ? DateUtilsHelper.parseFromDb(leaveDateStr) : null;

          bool isActiveThisMonth = joinDate.isBefore(lastDayOfMonth.add(const Duration(days: 1))) &&
              (leaveDate == null || leaveDate.isAfter(firstDayOfMonth.subtract(const Duration(days: 1))));

          if (isActiveThisMonth) {
            final periods = inactivePeriodsByBatch[batchId] ?? [];
            bool isLegacyInactive = batchActive[batchId] == false && periods.isEmpty;
            
            // If it's a legacy inactive batch with no periods, just skip completely
            if (isLegacyInactive) {
               continue;
            }

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
            
            bool isFullMonth = (effectiveStart == firstDayOfMonth) && (effectiveEnd == lastDayOfMonth);
            
            int startDay = effectiveStart.day > 30 ? 30 : effectiveStart.day;
            int endDay = effectiveEnd.day > 30 ? 30 : effectiveEnd.day;
            
            if (effectiveStart == firstDayOfMonth) startDay = 1;
            if (effectiveEnd == lastDayOfMonth) endDay = 30;
            
            int rawActiveDays = (endDay - startDay) + 1;
            if (rawActiveDays < 0) rawActiveDays = 0;
            if (rawActiveDays > 30) rawActiveDays = 30;

            int inactiveDaysCount = 0;
            if (periods.isNotEmpty) {
              List<Map<String, DateTime?>> parsedPeriods = periods.map((p) => <String, DateTime?>{
                'start': DateUtilsHelper.parseFromDb(p['start_date'] as String),
                'end': p['end_date'] != null ? DateUtilsHelper.parseFromDb(p['end_date'] as String) : null,
              }).toList();

              for (int d = startDay; d <= endDay; d++) {
                int actualD = d > lastDayOfMonth.day ? lastDayOfMonth.day : d;
                DateTime currentDate = DateTime(year, month, actualD);
                
                bool isInactive = false;
                for (var p in parsedPeriods) {
                  DateTime pStart = p['start']!;
                  DateTime? pEnd = p['end'];
                  
                  DateTime justDate = DateTime(currentDate.year, currentDate.month, currentDate.day);
                  DateTime justStart = DateTime(pStart.year, pStart.month, pStart.day);
                  
                  if (!justDate.isBefore(justStart)) {
                    if (pEnd == null) {
                      isInactive = true;
                      break;
                    } else {
                      DateTime justEnd = DateTime(pEnd.year, pEnd.month, pEnd.day);
                      if (!justDate.isAfter(justEnd)) {
                        isInactive = true;
                        break;
                      }
                    }
                  }
                }
                
                if (isInactive) {
                  inactiveDaysCount++;
                }
              }
            }
            
            int activeDays = rawActiveDays - inactiveDaysCount;
            if (activeDays < 0) activeDays = 0;
            
            if (inactiveDaysCount > 0 || !isFullMonth) {
              isPartialMonth = true;
            }

            if (activeDays > 0) {
              totalBatchMonthlyFee += ((finalBatchFee / 30) * activeDays).roundToDouble();
            }
          }
        }

        final existingRecord = existingRecordsByBatch[batchId];

        if (existingRecord == null) {
          if (totalBatchMonthlyFee > 0) {
            final feeRecord = FeeRecordModel(
              studentId: studentId,
              month: month,
              year: year,
              totalAmount: totalBatchMonthlyFee,
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

          if (totalBatchMonthlyFee == 0) {
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
          } else if (totalBatchMonthlyFee != currentTotalAmount) {
            bool isPastMonth = year < now.year || (year == now.year && month < now.month);
            
            if (!isPastMonth || isPartialMonth) {
              await db.update(
                _feeTable,
                {
                  'total_amount': totalBatchMonthlyFee,
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
  Future<void> addPaymentTransaction(int feeRecordId, double paymentAmount, {bool isSettled = false, String? note}) async {
    final db = await _dbHelper.database;
    final nowDateTimeStr = DateUtilsHelper.formatDateTimeForDb(DateTime.now());

    await db.transaction((txn) async {
      // 1. Insert into fee_transactions
      if (paymentAmount != 0) {
        await txn.insert('fee_transactions', {
          'fee_record_id': feeRecordId,
          'amount': paymentAmount,
          'payment_date': nowDateTimeStr,
          'note': note,
          'created_at': nowDateTimeStr,
        });
      }

      // 2. Fetch existing fee_record to get current paid_amount
      final record = await txn.query(_feeTable, where: 'id = ?', whereArgs: [feeRecordId]);
      if (record.isEmpty) return;

      final currentPaid = (record.first['paid_amount'] as num).toDouble();
      final currentlySettled = (record.first['is_settled'] as int?) == 1;
      final newPaidAmount = currentPaid + paymentAmount;

      final Map<String, dynamic> updateData = {
        'paid_amount': newPaidAmount,
        'is_settled': (isSettled || currentlySettled) ? 1 : 0,
        'updated_at': nowDateTimeStr,
      };
      if (paymentAmount > 0 || isSettled) {
        updateData['payment_date'] = nowDateTimeStr;
      }
      if (note != null && note.isNotEmpty) {
        updateData['note'] = note;
      }

      await txn.update(
        _feeTable,
        updateData,
        where: 'id = ?',
        whereArgs: [feeRecordId],
      );
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getFeeCollectionReport(int month, int year) async {
    final db = await _dbHelper.database;
    final monthStr = month.toString().padLeft(2, '0');
    final yearMonth = '$year-$monthStr';

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        t.id as transaction_id,
        t.amount as transaction_amount,
        t.payment_date,
        t.note as transaction_note,
        r.month as fee_month,
        r.year as fee_year,
        r.batch_details_snapshot,
        s.name as student_name,
        s.phone as student_phone
      FROM fee_transactions t
      JOIN fee_records r ON t.fee_record_id = r.id
      JOIN students s ON r.student_id = s.id
      WHERE t.payment_date LIKE ?
      ORDER BY t.payment_date DESC, s.name ASC
    ''', ['$yearMonth%']);

    return maps;
  }
}
