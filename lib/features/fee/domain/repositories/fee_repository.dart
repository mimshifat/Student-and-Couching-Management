import '../entities/fee_record.dart';
import '../entities/payment.dart';

abstract class FeeRepository {
  Future<List<FeeRecord>> getFeeRecordsForStudent(int studentId);
  Future<List<FeeRecord>> getPendingFeeRecords();
  Future<List<Payment>> getPaymentsForStudent(int studentId);
  
  Future<int> makePayment(Payment payment);
  Future<void> generateFeeRecords(int studentId, DateTime studentCreatedAt, double monthlyFee);
}
