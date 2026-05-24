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
}
