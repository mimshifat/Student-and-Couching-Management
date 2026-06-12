import '../entities/exam.dart';
import '../entities/result.dart';
import '../entities/detailed_result.dart';
import '../entities/batch_summary.dart';

abstract class ExamRepository {
  Future<int> insertExam(Exam exam);
  Future<int> updateExam(Exam exam);
  Future<int> deleteExam(int id);
  Future<List<Exam>> getExamsByBatch(int batchId);
  Future<List<Exam>> getAllExams();
  Future<List<Exam>> getFilteredExams({int? year, int? month, int? batchId, String? searchQuery});
  
  Future<void> saveResults(int examId, List<ExamResult> results);
  Future<List<ExamResult>> getResultsForExam(int examId);
  Future<List<ExamResult>> getResultsForStudent(int studentId);
  Future<List<ExamResult>> getResultsForStudentAndBatch(int studentId, int batchId);
  
  Future<List<DetailedResult>> getDetailedResultsForStudent(int studentId);
  Future<List<DetailedResult>> getDetailedResultsByBatch(int? batchId);

  // --- Performance-optimised queries (year filtered at DB level) ---
  /// Returns detailed results for a student filtered by year in SQL (no in-memory loop).
  Future<List<DetailedResult>> getDetailedResultsForStudentByYear(int studentId, int year);

  /// Returns one aggregate row per batch — avoids loading thousands of raw rows.
  Future<List<BatchSummary>> getBatchSummaries(int? batchId, int year);
}
