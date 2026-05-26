import '../entities/fee_record.dart';

abstract class FeeRepository {
  Future<List<FeeRecord>> getFeeRecordsForStudent(int studentId);
  Future<List<FeeRecord>> getPendingFeeRecords();
  
  Future<void> updatePaidAmount(int feeRecordId, double paidAmount, {bool isSettled = false, String? note});
  Future<void> generateFeeRecords(int studentId, DateTime studentCreatedAt);
}
