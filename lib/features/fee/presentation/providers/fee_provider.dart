import 'package:flutter/foundation.dart';
import '../../domain/entities/fee_record.dart';

import '../../domain/repositories/fee_repository.dart';
import '../../../student/domain/repositories/student_repository.dart';

class FeeProvider with ChangeNotifier {
  final FeeRepository _feeRepository;
  final StudentRepository _studentRepository;

  List<FeeRecord> _pendingFeeRecords = [];
  List<FeeRecord> get pendingFeeRecords => _pendingFeeRecords;

  List<FeeRecord> _studentFeeRecords = [];
  List<FeeRecord> get studentFeeRecords => _studentFeeRecords;



  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  FeeProvider(this._feeRepository, this._studentRepository);

  Future<void> loadPendingFeeRecords() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _pendingFeeRecords = await _feeRepository.getPendingFeeRecords();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadStudentFeeData(int studentId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Fetch student to get created date and monthly fee
      final student = await _studentRepository.getStudentById(studentId);
      if (student != null) {
        // Auto-generate missing cycles up to today
        await _feeRepository.generateFeeRecords(student.id!, student.createdAt);
      }

      _studentFeeRecords = await _feeRepository.getFeeRecordsForStudent(studentId);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updatePaidAmount(int feeRecordId, double paidAmount, int studentId) async {
    try {
      await _feeRepository.updatePaidAmount(feeRecordId, paidAmount);
      await loadStudentFeeData(studentId);
      await loadPendingFeeRecords();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
