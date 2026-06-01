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

  Future<bool> updateBatch(Batch batch, {DateTime? inactiveStartDate, DateTime? activationDate}) async {
    if (_hasConflict(batch)) {
      _errorMessage = 'Conflict: A batch is already scheduled for this day and time.';
      notifyListeners();
      return false;
    }
    
    try {
      await _repository.updateBatch(batch);
      
      if (batch.id != null) {
        if (inactiveStartDate != null) {
          await _repository.insertInactivePeriod(batch.id!, inactiveStartDate);
        } else if (activationDate != null) {
          final periods = await _repository.getInactivePeriods(batch.id!);
          final openPeriod = periods.where((p) => p['end_date'] == null).firstOrNull;
          if (openPeriod != null) {
            await _repository.updateInactivePeriod(openPeriod['id'], activationDate);
          }
        }
      }
      
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
    if (newBatch.scheduleDays!.isEmpty || newBatch.timeSlot!.isEmpty) return false;
    
    final newDays = newBatch.scheduleDays!.toLowerCase().split(RegExp(r'[^a-z]+')).where((d) => d.isNotEmpty).toSet();
    
    for (var b in _batches) {
      if (!b.isActive || b.id == newBatch.id) continue;
      if (b.scheduleDays == null || b.timeSlot == null) continue;
      
      final existingDays = b.scheduleDays!.toLowerCase().split(RegExp(r'[^a-z]+')).where((d) => d.isNotEmpty).toSet();
      
      // If there's an overlap in days, check time slot overlap
      if (newDays.intersection(existingDays).isNotEmpty) {
        if (_hasTimeOverlap(b.timeSlot!, newBatch.timeSlot!)) {
          return true;
        }
      }
    }
    return false;
  }

  bool _hasTimeOverlap(String slot1, String slot2) {
    if (slot1.trim() == slot2.trim()) return true;
    
    int? parseMinutes(String timeStr) {
      try {
        timeStr = timeStr.trim().toLowerCase();
        bool isPm = timeStr.contains('pm');
        timeStr = timeStr.replaceAll(RegExp(r'[a-z ]'), '');
        final parts = timeStr.split(':');
        if (parts.isEmpty) return null;
        int hours = int.parse(parts[0]);
        int minutes = parts.length > 1 ? int.parse(parts[1]) : 0;
        if (isPm && hours != 12) hours += 12;
        if (!isPm && hours == 12) hours = 0;
        return hours * 60 + minutes;
      } catch (e) {
        return null;
      }
    }
    
    final s1Parts = slot1.split('-');
    final s2Parts = slot2.split('-');
    if (s1Parts.length != 2 || s2Parts.length != 2) return slot1 == slot2;
    
    final start1 = parseMinutes(s1Parts[0]);
    final end1 = parseMinutes(s1Parts[1]);
    final start2 = parseMinutes(s2Parts[0]);
    final end2 = parseMinutes(s2Parts[1]);
    
    if (start1 == null || end1 == null || start2 == null || end2 == null) return slot1 == slot2;
    
    return start1 < end2 && start2 < end1;
  }
}
