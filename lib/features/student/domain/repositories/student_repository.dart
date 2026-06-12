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
}
