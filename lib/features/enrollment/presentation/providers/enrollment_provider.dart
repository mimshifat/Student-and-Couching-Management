import 'package:flutter/foundation.dart';
import '../../domain/entities/enrollment.dart';
import '../../domain/repositories/enrollment_repository.dart';

class EnrollmentProvider with ChangeNotifier {
  final EnrollmentRepository _repository;

  List<Enrollment> _activeEnrollments = [];
  List<Enrollment> get activeEnrollments => _activeEnrollments;

  List<Enrollment> _historyEnrollments = [];
  List<Enrollment> get historyEnrollments => _historyEnrollments;

  List<Enrollment> _enrollments = [];
  List<Enrollment> get enrollments => _enrollments;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  EnrollmentProvider(this._repository);

  Future<void> loadEnrollments() async {
    _isLoading = true;
    notifyListeners();
    try {
      _enrollments = await _repository.getAllEnrollments();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadStudentEnrollments(int studentId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _activeEnrollments = await _repository.getActiveEnrollments(studentId);
      _historyEnrollments = await _repository.getEnrollmentHistory(studentId);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> enrollStudent(Enrollment enrollment) async {
    try {
      final activeForStudent = await _repository.getActiveEnrollments(enrollment.studentId);
      if (activeForStudent.any((e) => e.batchId == enrollment.batchId)) {
        _errorMessage = 'Student is already enrolled in this batch.';
        notifyListeners();
        return false;
      }

      await _repository.enrollStudent(enrollment);
      await loadStudentEnrollments(enrollment.studentId);
      await loadEnrollments();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> leaveBatch(int enrollmentId, int studentId, DateTime leaveDate) async {
    try {
      await _repository.deactivateEnrollment(enrollmentId, leaveDate);
      await loadStudentEnrollments(studentId);
      await loadEnrollments();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateFeeOverride(int enrollmentId, int studentId, double? feeOverride) async {
    try {
      await _repository.updateFeeOverride(enrollmentId, feeOverride);
      await loadStudentEnrollments(studentId);
      await loadEnrollments();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<List<Enrollment>> getStudentsByBatch(int batchId) async {
    return await _repository.getStudentsByBatch(batchId);
  }
}
