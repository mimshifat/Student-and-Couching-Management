import '../entities/exam.dart';
import '../entities/result.dart';
import '../entities/detailed_result.dart';

abstract class ExamRepository {
  Future<int> insertExam(Exam exam);
  Future<int> updateExam(Exam exam);
  Future<int> deleteExam(int id);
  Future<List<Exam>> getExamsByBatch(int batchId);
  Future<List<Exam>> getAllExams();
  
  Future<void> saveResults(int examId, List<ExamResult> results);
  Future<List<ExamResult>> getResultsForExam(int examId);
  Future<List<ExamResult>> getResultsForStudent(int studentId);
  Future<List<ExamResult>> getResultsForStudentAndBatch(int studentId, int batchId);
  
  Future<List<DetailedResult>> getDetailedResultsForStudent(int studentId);
}
