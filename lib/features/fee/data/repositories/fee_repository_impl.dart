import 'package:sqflite/sqflite.dart' as sqflite;
import '../../domain/entities/fee_record.dart';
import '../../domain/entities/payment.dart';
import '../../domain/repositories/fee_repository.dart';
import '../models/fee_record_model.dart';
import '../models/payment_model.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/utils/date_utils.dart';

class FeeRepositoryImpl implements FeeRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  static const String _feeTable = 'fee_records';
  static const String _paymentTable = 'payments';

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
  Future<List<Payment>> getPaymentsForStudent(int studentId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _paymentTable,
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'payment_date DESC',
    );

    return List.generate(maps.length, (i) => PaymentModel.fromMap(maps[i]));
  }

  @override
  Future<void> generateFeeRecords(int studentId, DateTime admissionDate, double studentMonthlyFee) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();

    // Fetch all enrollments for this student
    final enrollmentsMap = await db.query('enrollments', where: 'student_id = ?', whereArgs: [studentId]);
    final batchesMap = await db.query('batches');
    
    // Create a lookup for batches
    Map<int, double> batchFees = {};
    for (var b in batchesMap) {
      batchFees[b['id'] as int] = (b['monthly_fee'] as num?)?.toDouble() ?? 0.0;
    }

    // Determine the start date (earliest of admission date or earliest join date)
    DateTime startDate = admissionDate;
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

        if (activeEnrollments.isEmpty) {
          // Private Student logic (using student's base monthly fee)
          DateTime effectiveStart = admissionDate.isAfter(firstDayOfMonth) ? admissionDate : firstDayOfMonth;
          int activeDays = lastDayOfMonth.difference(effectiveStart).inDays + 1;
          if (activeDays > daysInMonth) activeDays = daysInMonth;
          if (activeDays > 0) {
             totalMonthlyFee = (studentMonthlyFee / daysInMonth) * activeDays;
          }
        } else {
          // Batch Student logic
          for (var e in activeEnrollments) {
            final batchId = e['batch_id'] as int;
            final joinDate = DateUtilsHelper.parseFromDb(e['join_date'] as String);
            final leaveDateStr = e['leave_date'] as String?;
            final leaveDate = leaveDateStr != null ? DateUtilsHelper.parseFromDb(leaveDateStr) : null;
            final discount = (e['discount_amount'] as num?)?.toDouble() ?? 0.0;
            
            double batchFee = batchFees[batchId] ?? 0.0;
            double finalBatchFee = batchFee - discount;
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
            dueAmount: totalMonthlyFee,
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
  Future<int> makePayment(Payment payment) async {
    final db = await _dbHelper.database;
    
    int lastPaymentId = 0;

    await db.transaction((txn) async {
      // Fetch the specific fee record
      final List<Map<String, dynamic>> recordsMap = await txn.query(
        _feeTable,
        where: 'id = ?',
        whereArgs: [payment.feeRecordId],
      );

      if (recordsMap.isNotEmpty) {
        final recordId = recordsMap.first['id'] as int;
        final totalAmount = (recordsMap.first['total_amount'] as num).toDouble();
        final currentPaidAmount = (recordsMap.first['paid_amount'] as num).toDouble();
        
        final newPaidAmount = currentPaidAmount + payment.amount;
        double newDueAmount = totalAmount - newPaidAmount;
        if (newDueAmount < 0) newDueAmount = 0; // Prevent negative due visually

        final nowStr = DateUtilsHelper.formatForDb(DateTime.now());

        // Update fee record
        await txn.update(
          _feeTable,
          {
            'paid_amount': newPaidAmount,
            'due_amount': newDueAmount,
            'updated_at': nowStr,
          },
          where: 'id = ?',
          whereArgs: [recordId],
        );

        // Insert payment row
        final pModel = PaymentModel(
          feeRecordId: recordId,
          studentId: payment.studentId,
          amount: payment.amount,
          paymentDate: payment.paymentDate,
          note: payment.note,
          createdAt: DateTime.now(),
        );

        lastPaymentId = await txn.insert(_paymentTable, pModel.toMap());
      }
    });

    return lastPaymentId;
  }
}
