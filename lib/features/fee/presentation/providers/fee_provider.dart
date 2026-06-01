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
      // Auto-generate missing cycles for all students so they show up in the overview
      final students = await _studentRepository.getAllStudents();
      for (final student in students) {
        if (student.id != null) {
          await _feeRepository.generateFeeRecords(student.id!, student.createdAt);
        }
      }

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

  Future<bool> addPayment(int feeRecordId, double paymentAmount, int studentId, {bool isSettled = false, String? note}) async {
    try {
      await _feeRepository.addPaymentTransaction(feeRecordId, paymentAmount, isSettled: isSettled, note: note);
      await loadStudentFeeData(studentId);
      await loadPendingFeeRecords();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getCollectionReport(int month, int year) async {
    try {
      return await _feeRepository.getFeeCollectionReport(month, year);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return [];
    }
  }
}
