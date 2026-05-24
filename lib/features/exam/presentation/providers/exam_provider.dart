import 'package:flutter/foundation.dart';
import '../../domain/entities/exam.dart';
import '../../domain/entities/result.dart';
import '../../domain/repositories/exam_repository.dart';
import '../../../enrollment/domain/repositories/enrollment_repository.dart';

class ExamProvider with ChangeNotifier {
  final ExamRepository _repository;
  final EnrollmentRepository _enrollmentRepo;

  List<Exam> _exams = [];
  List<Exam> get exams => _exams;

  List<ExamResult> _currentResults = [];
  List<ExamResult> get currentResults => _currentResults;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  ExamProvider(this._repository, this._enrollmentRepo) {
    loadAllExams();
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
    notifyListeners();

    try {
      final existingResults = await _repository.getResultsForExam(exam.id!);
      
      if (existingResults.isNotEmpty) {
        _currentResults = existingResults;
      } else {
        // Generate blank results for active students
        final enrolled = await _enrollmentRepo.getStudentsByBatch(exam.batchId);
        _currentResults = enrolled.map((e) => ExamResult(
          examId: exam.id!,
          studentId: e.studentId,
          batchId: exam.batchId,
          createdAt: DateTime.now(),
          studentName: e.studentName,
          isAbsent: false,
        )).toList();
      }
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
