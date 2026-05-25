import '../entities/enrollment.dart';

abstract class EnrollmentRepository {
  Future<int> enrollStudent(Enrollment enrollment);
  Future<int> deactivateEnrollment(int id, DateTime leaveDate);
  Future<int> updateFeeOverride(int id, double? feeOverride);
  Future<List<Enrollment>> getActiveEnrollments(int studentId);
  Future<List<Enrollment>> getEnrollmentHistory(int studentId);
  Future<List<Enrollment>> getAllEnrollments();
  Future<List<Enrollment>> getStudentsByBatch(int batchId);
  Future<bool> isStudentActive(int studentId);
}
