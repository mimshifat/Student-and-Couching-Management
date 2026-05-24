import 'package:flutter/foundation.dart';
import '../../domain/entities/enrollment.dart';
import '../../domain/repositories/enrollment_repository.dart';

class EnrollmentProvider with ChangeNotifier {
  final EnrollmentRepository _repository;

  List<Enrollment> _activeEnrollments = [];
  List<Enrollment> get activeEnrollments => _activeEnrollments;

  List<Enrollment> _historyEnrollments = [];
  List<Enrollment> get historyEnrollments => _historyEnrollments;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  EnrollmentProvider(this._repository);

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
      await _repository.enrollStudent(enrollment);
      await loadStudentEnrollments(enrollment.studentId);
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
