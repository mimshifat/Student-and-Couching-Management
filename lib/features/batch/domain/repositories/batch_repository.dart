import '../entities/batch.dart';

abstract class BatchRepository {
  Future<int> insertBatch(Batch batch);
  Future<int> updateBatch(Batch batch);
  Future<int> deleteBatch(int id);
  Future<Batch?> getBatchById(int id);
  Future<List<Batch>> getAllBatches();
  
  // Inactive periods
  Future<int> insertInactivePeriod(int batchId, DateTime startDate, {DateTime? endDate});
  Future<void> updateInactivePeriod(int id, DateTime endDate);
  Future<List<Map<String, dynamic>>> getInactivePeriods(int batchId);
}
