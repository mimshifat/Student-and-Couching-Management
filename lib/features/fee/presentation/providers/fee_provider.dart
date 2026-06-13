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

  /// Tracks whether fee generation has run this session.
  /// Avoids re-running the expensive O(students×months) generation on every screen load.
  bool _hasGeneratedFees = false;

  /// Incremented every time pending records are reloaded, so the UI can detect data changes.
  int _dataVersion = 0;
  int get dataVersion => _dataVersion;

  FeeProvider(this._feeRepository, this._studentRepository);

  Future<void> loadPendingFeeRecords({bool forceRegenerate = false, int? year, bool includePreviousUnpaid = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Only run the expensive generation loop on first load or explicit refresh
      if (!_hasGeneratedFees || forceRegenerate) {
        // CRITICAL: Only regenerate for ACTIVE students (leave_date IS NULL).
        // Previous students (5,000) have finalized records — regenerating them
        // on every launch caused multi-minute freezes at scale.
        final activeStudentIds = await _studentRepository.getActiveStudentIds();
        for (final studentId in activeStudentIds) {
          final student = await _studentRepository.getStudentById(studentId);
          if (student != null) {
            await _feeRepository.generateFeeRecords(student.id!, student.createdAt);
          }
        }
        _hasGeneratedFees = true;
      }

      // Pass year to DB query so only relevant records are loaded into memory
      _pendingFeeRecords = await _feeRepository.getPendingFeeRecords(
        year: year,
        includePreviousUnpaid: includePreviousUnpaid,
      );
      _dataVersion++;
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
      // Regenerate only for this specific student (fast)
      await loadStudentFeeData(studentId);
      // Lightweight reload: fetch current year's records only (no full regeneration)
      final int currentYear = DateTime.now().year;
      _pendingFeeRecords = await _feeRepository.getPendingFeeRecords(year: currentYear);
      _dataVersion++;
      notifyListeners();
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
