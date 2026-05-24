import '../entities/routine.dart';

abstract class RoutineRepository {
  Future<int> insertRoutine(Routine routine);
  Future<int> deleteRoutine(int id);
  Future<List<Routine>> getRoutinesByBatch(int batchId);
  Future<List<Routine>> getRoutinesByDay(String dayOfWeek);
}
