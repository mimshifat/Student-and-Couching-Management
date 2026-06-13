import '../entities/fee_record.dart';

abstract class FeeRepository {
  Future<List<FeeRecord>> getFeeRecordsForStudent(int studentId);
  /// [year] — when provided, only returns records for that year.
  /// [includePreviousUnpaid] — when true, also includes unpaid records from years before [year].
  Future<List<FeeRecord>> getPendingFeeRecords({int? year, bool includePreviousUnpaid = false});
  
  Future<void> addPaymentTransaction(int feeRecordId, double paymentAmount, {bool isSettled = false, String? note});
  Future<void> generateFeeRecords(int studentId, DateTime studentCreatedAt);
  Future<List<Map<String, dynamic>>> getFeeCollectionReport(int month, int year);
}
