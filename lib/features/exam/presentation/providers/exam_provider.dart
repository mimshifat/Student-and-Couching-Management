import 'package:flutter/foundation.dart';
import '../../domain/entities/exam.dart';
import '../../domain/entities/result.dart';
import '../../domain/entities/detailed_result.dart';
import '../../domain/entities/batch_summary.dart';
import '../../domain/repositories/exam_repository.dart';
import '../../../enrollment/domain/repositories/enrollment_repository.dart';

class ExamProvider with ChangeNotifier {
  final ExamRepository _repository;
  final EnrollmentRepository _enrollmentRepo;

  List<Exam> _exams = [];
  List<Exam> get exams => _exams;

  List<ExamResult> _currentResults = [];
  List<ExamResult> get currentResults => _currentResults;

  List<DetailedResult> _detailedResults = [];
  List<DetailedResult> get detailedResults => _detailedResults;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  ExamProvider(this._repository, this._enrollmentRepo) {
    loadAllExams();
  }

  Future<void> loadDetailedResultsForStudent(int studentId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _detailedResults = await _repository.getDetailedResultsForStudent(studentId);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<DetailedResult> _batchSummaryResults = [];
  List<DetailedResult> get batchSummaryResults => _batchSummaryResults;

  Future<void> loadDetailedResultsByBatch(int? batchId, {int? year, int? startMonth, int? endMonth}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _batchSummaryResults = await _repository.getDetailedResultsByBatch(
          batchId, year: year, startMonth: startMonth, endMonth: endMonth);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Performance-optimised provider methods ---

  List<DetailedResult> _yearFilteredResults = [];
  List<DetailedResult> get yearFilteredResults => _yearFilteredResults;

  /// Loads student results filtered by time at DB level — no in-memory loop.
  Future<void> loadDetailedResultsFiltered(int studentId, {int? year, int? startMonth, int? endMonth}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _yearFilteredResults =
          await _repository.getDetailedResultsForStudentFiltered(
              studentId, year: year, startMonth: startMonth, endMonth: endMonth);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<BatchSummary> _batchSummaries = [];
  List<BatchSummary> get batchSummaries => _batchSummaries;

  /// Loads one aggregate row per batch — avoids loading thousands of raw rows.
  Future<void> loadBatchSummaries(int? batchId, {int? year, int? startMonth, int? endMonth}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _batchSummaries = await _repository.getBatchSummaries(
          batchId, year: year, startMonth: startMonth, endMonth: endMonth);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAllExams() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _exams = await _repository.getAllExams();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadFilteredExams({int? year, int? startMonth, int? endMonth, int? batchId, String? searchQuery}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _exams = await _repository.getFilteredExams(
        year: year,
        startMonth: startMonth,
        endMonth: endMonth,
        batchId: batchId,
        searchQuery: searchQuery,
      );
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addExam(Exam exam) async {
    try {
      await _repository.insertExam(exam);
      await loadAllExams();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateExam(Exam exam) async {
    try {
      await _repository.updateExam(exam);
      await loadAllExams();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteExam(int id) async {
    try {
      await _repository.deleteExam(id);
      await loadAllExams();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Prepares the result entry screen by loading existing results or 
  // generating blank ones for all currently enrolled students in the batch
  Future<void> prepareResultsForExam(Exam exam) async {
    _isLoading = true;
    _errorMessage = null;
    _currentResults = []; // ← clear stale data from previous exam immediately
    notifyListeners();

    try {
      final existingResults = await _repository.getResultsForExam(exam.id!);
      final enrolled = await _enrollmentRepo.getStudentsEnrolledOnDate(exam.batchId, exam.examDate);
      
      final enrolledStudentIds = enrolled.map((e) => e.studentId).toSet();
      
      _currentResults = [];
      for (final result in existingResults) {
        // Keep result if they are still enrolled OR if they have actual data
        if (enrolledStudentIds.contains(result.studentId) || 
            result.obtainedMarks != null || 
            result.isAbsent || 
            result.hasPaid) {
          _currentResults.add(result);
        }
      }
      
      final existingStudentIds = _currentResults.map((r) => r.studentId).toSet();

      for (final student in enrolled) {
        if (!existingStudentIds.contains(student.studentId)) {
          _currentResults.add(ExamResult(
            examId: exam.id!,
            studentId: student.studentId,
            batchId: exam.batchId,
            createdAt: DateTime.now(),
            studentName: student.studentName,
            isAbsent: false,
          ));
        }
      }

      // Sort by student name to maintain a consistent order
      _currentResults.sort((a, b) => (a.studentName ?? '').compareTo(b.studentName ?? ''));
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateResultMarks(int studentId, double marks) {
    final idx = _currentResults.indexWhere((r) => r.studentId == studentId);
    if (idx != -1) {
      _currentResults[idx] = _currentResults[idx].copyWith(obtainedMarks: marks, isAbsent: false);
      notifyListeners();
    }
  }

  /// Updates marks in-memory WITHOUT triggering a UI rebuild.
  /// Use this inside TextFields to avoid resetting the keyboard/scroll position.
  void updateResultMarksSilent(int studentId, double marks) {
    final idx = _currentResults.indexWhere((r) => r.studentId == studentId);
    if (idx != -1) {
      _currentResults[idx] = _currentResults[idx].copyWith(obtainedMarks: marks, isAbsent: false);
      // No notifyListeners() — keeps TextFields stable during typing
    }
  }

  /// Clears marks to null in-memory WITHOUT triggering a UI rebuild.
  /// Called when the user clears/empties a marks TextField.
  void clearResultMarksSilent(int studentId) {
    final idx = _currentResults.indexWhere((r) => r.studentId == studentId);
    if (idx != -1) {
      _currentResults[idx] = _currentResults[idx].copyWith(obtainedMarks: null);
      // No notifyListeners() — keeps TextFields stable
    }
  }

  void updateResultAbsent(int studentId, bool isAbsent) {
    final idx = _currentResults.indexWhere((r) => r.studentId == studentId);
    if (idx != -1) {
      _currentResults[idx] = _currentResults[idx].copyWith(
        isAbsent: isAbsent, 
        obtainedMarks: isAbsent ? null : _currentResults[idx].obtainedMarks
      );
      notifyListeners();
    }
  }

  void updateResultHasPaid(int studentId, bool hasPaid) {
    final idx = _currentResults.indexWhere((r) => r.studentId == studentId);
    if (idx != -1) {
      _currentResults[idx] = _currentResults[idx].copyWith(hasPaid: hasPaid);
      notifyListeners();
    }
  }

  Future<bool> saveResults(int examId) async {
    try {
      await _repository.saveResults(examId, _currentResults);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
