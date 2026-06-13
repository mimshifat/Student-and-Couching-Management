import '../entities/enrollment.dart';
import '../entities/annual_report_entry.dart';

abstract class EnrollmentRepository {
  Future<int> enrollStudent(Enrollment enrollment);
  Future<int> deactivateEnrollment(int id, DateTime leaveDate);
  Future<int> updateFeeOverride(int id, double? feeOverride);
  Future<List<Enrollment>> getActiveEnrollments(int studentId);
  Future<List<Enrollment>> getEnrollmentHistory(int studentId);
  Future<List<Enrollment>> getAllEnrollments();
  Future<List<Enrollment>> getStudentsByBatch(int batchId);
  Future<bool> isStudentActive(int studentId);

  /// Returns raw enrollment rows for [year], LEFT-JOINed with students so that
  /// soft-deleted students are included. Grouping into [AnnualReportEntry] is
  /// done in the provider/Dart layer.
  Future<List<Map<String, dynamic>>> getEnrollmentsByYear(int year);

  /// Returns a sorted list of distinct years (descending) that have at least
  /// one enrollment record — used to populate the year filter dropdown.
  Future<List<int>> getDistinctEnrollmentYears();
}
