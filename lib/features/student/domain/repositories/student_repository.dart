import '../entities/student.dart';
import '../entities/student_summary.dart';

abstract class StudentRepository {
  Future<int> insertStudent(Student student);
  Future<int> updateStudent(Student student);
  Future<int> deleteStudent(int id);
  Future<Student?> getStudentById(int id);
  Future<List<Student>> getAllStudents();
  Future<List<Student>> searchStudents(String query);

  /// Fetches students with their status calculated via SQL JOIN, and applies filters.
  /// This avoids O(N*E) in-memory loops.
  Future<List<StudentSummary>> getFilteredStudentSummaries({
    String? status,
    String? className,
    int? batchId,
    String? searchQuery,
  });
  Future<List<Student>> getStudentsByBatch(int batchId);

  /// Returns distinct non-null class names — much cheaper than loading all students.
  Future<List<String>> getDistinctClassNames();

  /// Returns IDs of students with at least one active enrollment (leave_date IS NULL).
  /// Used to skip fee generation for previous/left students.
  Future<List<int>> getActiveStudentIds();

  /// Returns phone number of a single student — avoids loading all students just for SMS.
  Future<String?> getStudentPhoneById(int id);
}
