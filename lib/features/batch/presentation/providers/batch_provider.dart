import 'package:flutter/foundation.dart';
import '../../domain/entities/batch.dart';
import '../../domain/repositories/batch_repository.dart';

class BatchProvider with ChangeNotifier {
  final BatchRepository _repository;

  List<Batch> _batches = [];
  List<Batch> get batches => _batches;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  BatchProvider(this._repository) {
    loadBatches();
  }

  Future<void> loadBatches() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _batches = await _repository.getAllBatches();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addBatch(Batch batch) async {
    if (_hasConflict(batch)) {
      _errorMessage = 'Conflict: A batch is already scheduled for this day and time.';
      notifyListeners();
      return false;
    }
    
    try {
      await _repository.insertBatch(batch);
      await loadBatches();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateBatch(Batch batch) async {
    if (_hasConflict(batch)) {
      _errorMessage = 'Conflict: A batch is already scheduled for this day and time.';
      notifyListeners();
      return false;
    }
    
    try {
      await _repository.updateBatch(batch);
      await loadBatches();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteBatch(int id) async {
    try {
      await _repository.deleteBatch(id);
      await loadBatches();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  bool _hasConflict(Batch newBatch) {
    if (newBatch.scheduleDays == null || newBatch.timeSlot == null) return false;
    
    for (var b in _batches) {
      if (!b.isActive) continue;
      if (b.id == newBatch.id) continue;
      
      if (b.scheduleDays == newBatch.scheduleDays && b.timeSlot == newBatch.timeSlot) {
        return true;
      }
    }
    return false;
  }
}
