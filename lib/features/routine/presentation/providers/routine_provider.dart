import 'package:flutter/foundation.dart';
import '../../domain/entities/routine.dart';
import '../../domain/repositories/routine_repository.dart';

class RoutineProvider with ChangeNotifier {
  final RoutineRepository _repository;

  List<Routine> _routines = [];
  List<Routine> get routines => _routines;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  RoutineProvider(this._repository);

  Future<void> loadRoutinesByBatch(int batchId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _routines = await _repository.getRoutinesByBatch(batchId);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadRoutinesByDay(String dayOfWeek) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _routines = await _repository.getRoutinesByDay(dayOfWeek);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addRoutine(Routine routine) async {
    try {
      await _repository.insertRoutine(routine);
      await loadRoutinesByBatch(routine.batchId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteRoutine(int id, int batchId) async {
    try {
      await _repository.deleteRoutine(id);
      await loadRoutinesByBatch(batchId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
