import '../entities/fee_record.dart';

abstract class FeeRepository {
  Future<List<FeeRecord>> getFeeRecordsForStudent(int studentId);
  Future<List<FeeRecord>> getPendingFeeRecords();
  
  Future<void> addPaymentTransaction(int feeRecordId, double paymentAmount, {bool isSettled = false, String? note});
  Future<void> generateFeeRecords(int studentId, DateTime studentCreatedAt);
  Future<List<Map<String, dynamic>>> getFeeCollectionReport(int month, int year);
}
