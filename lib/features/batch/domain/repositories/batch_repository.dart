import '../entities/batch.dart';

abstract class BatchRepository {
  Future<int> insertBatch(Batch batch);
  Future<int> updateBatch(Batch batch);
  Future<int> deleteBatch(int id);
  Future<Batch?> getBatchById(int id);
  Future<List<Batch>> getAllBatches();
}
